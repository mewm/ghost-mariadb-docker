[Fig]: http://www.fig.sh
[Docker]: https://www.docker.com
[boot2docker]: http://boot2docker.io
[OSXContainerHost]: https://github.com/SeerUK/OSXContainerHost
[ghost-config-gist]: https://gist.github.com/mewm/778644a11b0f28670fe4
[fig-yml-reference]: http://www.fig.sh/yml.html
[fig-cli-reference]: http://www.fig.sh/cli.html
[ghost-mariadb-fig-repo]: https://github.com/mewm/ghost-mariadb-fig
[docker-doc]: https://docs.docker.com/userguide
[docker-hub]: https://registry.hub.docker.com
[docker-performance-paper]: http://stackoverflow.com/questions/21889053/what-is-the-runtime-performance-cost-of-a-docker-container

_Disclaimer: I'm no docker expert whatsoever, nor do I claim that this is __the way__ to do it, but just my 1337 cents_

I just recently set this blog ghost blog up, so I decided to write this post along with it. This post elaborates the setup which is currently hosted on Digital Ocean.

Ghost is a widely used blogging platform written entirely in javascript, both on the client and on the server using node and expressjs. By default, it uses a SQLite instance for persistence, but I've never really used nor liked SQLite that much, and also to fit an even better use-case for using Docker, while maintaining separation of concerns. So we're splitting up the containers by responsibility and using MariaDB as our "favorite database"!

We will split the responsibilities up in Docker containers which runs completely isolated from each other. One for the ghost platform, one for the database and one for data only. The data container will host all data, which will be accessible from within our containers as mounted volumes.
And with a few small bash scripts, we will get the essentials bootstrapped and everything running.

Using Fig, we can easily manage our Docker containers and their respective builds. If you've never played around with Docker before, I would encourage you to go familiarize your self with [it's documentation][docker-doc] before jumping in to fig. 
Fig provides a clean interface for managing containers, and lets you handle all your app's services from a single source.
Fig also has a number of other really nice features, such as scaling, though I haven't tried it yet.


# Tools we're gonna use
* [Fig]
* [Docker] - you might need [boot2docker] if you're running OSX. [OSXContainerHost] is actually my favorite choice for proxying docker on OSX, [but it has a known issue with the devicemapper when using fig.](https://github.com/SeerUK/OSXContainerHost/issues/2)   
* Your favorite editor!


# Problem
I want a Ghost blogging platform connected with MariaDB. I also want to be able to grab backups, and update my theme easily. Ohh, and I want that shit dockerized and managed with fig!


# Objectives
So we have our quite abstract problem. Let's split it into smaller objectives:

* [Create a Dockerfile for a data-only container](#dataonlydocker)
* [Create a Dockerfile for setting up MariaDB](#mariadbdockerfile)
    - [Create a script to start the server](#mariadbstartscript)
    - [Create a one-time script for creating a default set of user credentials](#mariadbcreateuserscript)
* [Create a Dockerfile for setting up Ghost](#ghostdocker)
    - [Add our ghost config.js file](#ghostconfig)
    - [Create a script to checkout/update our theme and start the server](#ghoststartscript)
* [Compose a fig.yml to orchestrate all our app's services](#fig)
* [Manage the containers with Fig](#fig)
* [Optional: Create a bash scripts to create/restore backups](#backuprestorescripts)
* [Optional: Setup a virtual host for nginx to proxy requests to our blog](#nginxvirtualhost)


## Data-only Dockerfile
<a id="dataonlydocker"></a>

```php
FROM busybox
MAINTAINER Dennis Micky Jensen <dj@miinto.com>

# Create default ghost content dirs
RUN mkdir -p /var/www/ghost/content/apps
RUN mkdir -p /var/www/ghost/content/images
RUN mkdir -p /var/www/ghost/content/themes
RUN mkdir -p /var/www/ghost/content/data
```
Here we're instructing Docker to create a few default directories when building our image. The reason for creating these folders, is that the content folder will be mounted from the data container and might risk deleting the initial folders that came with the installation of ghost. If these folders doesn't exist, ghost wont run.
Initially, I didn't event want to have a Dockerfile for this container (you can use either an image or a Dockerfile), but somehow without the Dockerfile, I could not get data to persist over restarts, so yeah, fuck that. 
The base image we're using here; ```busybox```, is just a really small image, which is perfect for our data-only container. You can find already existing images on [Docker Hub][docker-hub]


## MariaDB Dockerfile
<a id="mariadbdocker"></a>

```dockerfile
FROM ubuntu:trusty
MAINTAINER Dennis Micky Jensen <root@mewm.org>

# Download MariaDB
RUN apt-get update && \
    apt-get install -y mariadb-server pwgen && \
    rm -rf /var/lib/mysql/* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set bind address to 0.0.0.0 and enforce port
RUN sed -i -r 's/bind-address.*$/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
RUN sed -i -r 's/port.*$/port = 3306'/ /etc/mysql/my.cnf

# Add bash scripts for creating a user and run server
ADD create-mariadb-user.sh /create-mariadb-user.sh
ADD run-mariadb.sh /run-mariadb.sh
RUN chmod 775 /*.sh

# To avoid mysql whining about this variable
ENV TERM dumb 

# Set default entry point
CMD ["/run-mariadb.sh"]
```
There are more fine and optimized base images for databases, than just ubuntu:trusty, but I went with a straight ubuntu for simplicity sake. 
The important thing to notice here, is opening up for connections outside localhost, and adding the two bash scripts we need. The containers will have there "links to other containers" defined in the ```fig.yml``` file. Finally, we're instructing the container to invoke ```run-mariadb.sh``` as the default command upon invocation.


### MariaDB start script
<a id="mariadbstartscript"></a>

```bash
#!/bin/bash

VOLUME_HOME="/var/lib/mysql"
if find ${VOLUME_HOME} -maxdepth 0 -empty | read v; then
    echo " -> Installation detected in $VOLUME_HOME"
    echo " -> Installing MariaDB"
    mysql_install_db > /dev/null 2>&1
    echo " -> Done!"
    /create-mariadb-admin-user.sh
else
    echo "-> Booting on existing volume!"
fi

exec mysqld_safe
```
This script is the default command for our database container. When initial boot is detected, we bootstrap the server and invoke our create-user script outlined below, then we start our server.


### Create database user script
<a id="mariadbcreateuserscript"></a>

```bash
#!/bin/bash
/usr/bin/mysqld_safe > /dev/null 2>&1 &

RET=1
while [[ RET -ne 0 ]]; do
    sleep 5
    mysql -uroot -e "status" > /dev/null 2>&1
    RET=$?
done

mysql -uroot -e "CREATE USER '$DEFAULT_USER'@'%' IDENTIFIED BY '$DEFAULT_PASS'"
mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '$DEFAULT_USER'@'%' WITH GRANT OPTION"
mysql -uroot -e "CREATE DATABASE ghost"

mysqladmin -uroot shutdown
```

This script will be invoked from ```run-mariadb.sh``` when initial boot is detected. We start our database instance, waits until the instance is ready, 
then creating the user with credentials which we will define later in our ```fig.yml```.


## Ghost Dockerfile
<a id="ghostdocker"></a>

```
FROM dockerfile/nodejs
MAINTAINER Dennis Micky Jensen "root@mewm.org"

# Download and install latest version of ghost
RUN cd /tmp 
RUN wget https://ghost.org/zip/ghost-latest.zip 
RUN unzip ghost-latest.zip -d /ghost 
RUN rm -f ghost-latest.zip 
RUN mkdir -p /var/www
RUN mv /ghost /var/www 
RUN cd /var/www/ghost && npm install --production 

# Move ghost into the system neighbourhood. Welcome yo!
ENV HOME /var/www/ghost
RUN useradd ghost --home /var/www/ghost
WORKDIR /var/www/ghost

# Add config and script to start the engine
ADD config.js /var/www/ghost/config.js
ADD run-ghost.sh /run-ghost.sh
RUN chmod 0500 /run-ghost.sh

CMD /run-ghost.sh
```
When building the image from this Dockerfile, we download and install the latest version of ghost. We also create and configure a user which will run the ghost app.
You might have noticed, that there is next to none environment variables set. They will be defined in ```fig.yml``` which we will get to later. 
You can basically decide your self, how wanna split the instructions between fig and the Dockerfile. I just went for a solution I thought was adequate, but frankly, I'm not quite sure about the best practices here though. 

### Ghost config file
<a id="ghostconfig"></a>

[This gist][ghost-config-gist] provides a quite generic template for ```config.js```, that's more or less completely configurable with environment variables. 
To be honest, I don't remember where I got this from, so I don't know who to credit :(
I have not considered emailing in this setup, but it's only a couple of environment variables you need to add, which you can spoof from the file.


### Ghost boot script
<a id="ghostbootscript"></a>

```
#!/bin/bash
_theme_source_destination="${HOME}/content/themes/casper"

if [ -d ${_theme_source_destination} ]; then
    cd ${_theme_source_destination} && git pull origin master
    cd $HOME
else
    git clone ${THEME_SOURCE} $HOME/content/themes/casper
fi

chown -R ghost /var/www/ghost
su ghost -c "npm start"
```
Here we are detecting if the theme (also configured in ```fig.yml```) has been checked out from git yet, and if not, we pull the latest changes. This script runs every time you start the container, so if you've pushed changes to your theme, it's just a matter of restarting your container to get the updates.
Then we ensure ghost ownership to our web folder, and start the express server. This might not be the most secure procedure, but it floats my boat for now :P

## Fig
<a id="fig"></a>

This is where we define our services for our whole application. Fig will take care of building images and starting containers.
Here is how our ```fig.yml``` looks like:

```yml
data:
  build: ./data
  volumes:
    - /var/lib/mysql
    - /var/www/ghost/content
db:
  build: ./mariadb
  ports:
    - "3305:3305"
  volumes_from:
    - data
  environment:
    - DEFAULT_USER=ghost # A user with this name will be created
    - DEFAULT_PASS=foobarbaz
    - PORT=3305
web:
  build: ./ghost
  ports:
    - "2368:2368"
  links:
    - db:database
  volumes_from:
    - data
  environment:
    - DB_HOST=database
    - DB_CLIENT=mysql
    - DB_USER=ghost
    - DB_PASSWORD=foobarbaz
    - DB_PORT=3305
    - DB_DATABASE=ghost
    - URL=http://localhost:2368/
    - NODE_ENV=production # production/development
    - THEME_SOURCE=https://github.com/mewm/ghost-theme # Git repo to fetch theme from
```
As you can see, configuring Docker containers with Fig is really easy. [There is fig counterpart to almost all options that goes with ```docker run```][fig-yml-reference]
As vaguely mentioned before, you can define your instructions either in ```fig.yml``` or the ```Dockerfile```, and mix it up that way, to whatever fits your use-case best.
For each service, I have a sub folder containing its Dockerfile and related scripts. The ```build``` options specifies the path to the Dockerfile. The only mandatory option in the ```fig.yml``` is ```build``` or ```image```. Using image, you even need a Dockerfile.
Now we have structured the essentials for our application, we're ready to fire it up! A more complete cli reference can be found [here][fig-cli-reference].

```bash
# Build application from our fig.yml 
$ fig build

# Start our application. This runs the CMD specified in the Dockerfiles
$ fig up
```
An there you have it! Both commands aggregates a fair amount of output from each container, but hopefully you should see everything go pretty smoothly. Fig will stay open if no exit code is detected. You might wanna throw in a ```-d``` to run it "Detached mode".

When you're playing around with builds, it's useful to remove containers you don't use anymore. The ```rm``` command removes all stopped containers. By specifying a service name, you can target specific services. You can start and stop existing containers with ```start``` and ```stop```. 
It's worth mentioning that ```up``` doesn't rebuild images automatically, so if you've made changes to a Dockerfile, you will need to ```build``` it again. To get an overview of your containers, ```ps``` will do the job, just as with the docker cli. If your container has a shell (busybox doesn't) and you wanna sneak around inside your container, you can start an interactive shell with ```fig run web /bin/bash``` (currently, I'm experiencing an issue where this command actually just hangs. By waiting 5 seconds and then CTRL+C it actually continues).

A few caveats I've encountered, which is worth mentioning:
* Docker seems to give a shit about your low-volume overly expensive SSD disk, and tends to build up quite a few containers and images occupying a lot of space. Just try do a ```docker ps -a``` (shows all your containers), ```docker images``` (shows all images). They don't even have an easy way of cleaning it up, but luckily there is this little naughty one-line that does the job:  ```docker rm $(docker ps -a -q) && docker rmi $(docker images -q)``` - Warning: all your shit will be lost. If you're on OSX, you can also just destroy your VM box that contains docker.
* Maybe you've noticed, but the data-only container isn't actually running. That's because even though the container is stopped, the volumes are still active. This took me quite a while to figure out :P


## Backup and restore scripts
<a id="backuprestorescripts"></a>

This is where we take advantage of our mountable volumes on our data-only.container.

```
# Backup db data to a tar file
docker run --volumes-from ghostmariadbfig_data_1 -v $(pwd)/backups:/backups ubuntu tar cvf /backups/db_backup_$(date +%Y_%m_%d).tar /var/lib/mysql

# Restore database backup
docker run --volumes-from ghostmariadbfig_data_1 -v $(pwd)/backups:/backups ubuntu tar xvf /backups/db_backup_<date of backup>.tar


# Backup ghost content data to tar file
docker run --volumes-from ghostmariadbfig_data_1 -v $(pwd)/backups:/backups ubuntu tar cvf /backups/ghost_backup_$(date +%Y_%m_%d).tar /var/www/ghost/content
 
# Restore ghost content backup
docker run --volumes-from ghostmariadbfig_data_1 -v $(pwd)/backups:/backups ubuntu tar xvf /backups/ghost_backup_<date of backup>.tar
```

Here we mount the volumes from our data container, and also mount a host directory to a backup folder inside the container. Then we create a tar file from our mounted data volume and archives it in the mounted host folder.
The name ```ghostmariadbfig_data_1``` is just the default name fig gave our data-only container. You can spoof the name of your containers with ```fig ps```.
This might look pretty wicked, but if you chunk them down to bits, it's easier to wrap your head around it. Here is what happens:

* ```docker run``` - command to run a container
* ```--volumes-from ghostmariadbfig_data_1``` - Mounts the volumes from our data container so they are accessible inside our temporary ubuntu container.
* ```-v $(pwd)/backups:/backups``` - Mounts our ./backups as /backups inside our container
* ```ubuntu``` - The image we wish to template our container. This will be downloaded automatically if not found locally.
* ```tar cvf /backups/ghost_backup_$(date +%Y_%m_%d).tar /var/www/ghost/content``` - This is the command sequence to run once the container is booted. We create a tar from our wanted data and saves named todays date. When the operation is done and docker receives an exit code, the container will shut down automatically.

To restore each backup, all you have to do, is extract the tar file instead of creating it. Remember to change the file name :P
It's fairly easy to rewrite these snippets to grab the tar filename from a command line argument, [just take a look at this project on github][ghost-mariadb-fig-repo]


## Nginx virtual host
<a id="nginxvirtualhost"></a>

If you like me is a sucker for nginx, and you host several sites on your server already (which is probably are occupying port 80), you can use a virtual host to proxy the requests to your ghost app. There is similar script out there for apache as well.

```
server {
   listen 0.0.0.0:80;
   server_name http://blog.mewm.org; #replace this line with your domain
   access_log /var/log/nginx/blog.mewm.org.log; #replace this with any log name
 
   location / {
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header HOST $http_host;
       proxy_set_header X-NginX-Proxy true;
       proxy_pass http://127.0.0.1:2368;
       proxy_redirect off;
   }
 }
```
 
 
## Final words
All the code outlined here is [available on github][ghost-mariadb-fig-repo].
I think Docker and fig are amazing tools and I use them as much as possible. Getting your application up and running is a blaze, and if your worried about any performance overhead in your production environments, check this [SO post][docker-performance-paper]. It shows very little overhead, which even in the short run is hugely compensated for in flexibility.