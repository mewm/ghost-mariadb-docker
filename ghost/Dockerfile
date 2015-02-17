FROM dockerfile/nodejs
MAINTAINER Dennis Micky Jensen "root@mewm.org"

ENV HOME /var/www/ghost


RUN cd /tmp 
RUN wget https://ghost.org/zip/ghost-latest.zip 
RUN unzip ghost-latest.zip -d /ghost 
RUN rm -f ghost-latest.zip 

RUN mkdir -p /var/www
RUN mv /ghost /var/www 
RUN cd /var/www/ghost && npm install --production 

RUN useradd ghost --home /var/www/ghost

ADD config.js /var/www/ghost/config.js

WORKDIR /var/www/ghost

ADD run-ghost.sh /run-ghost.sh
RUN chmod 0500 /run-ghost.sh

CMD /run-ghost.sh


