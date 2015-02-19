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


