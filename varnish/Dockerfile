FROM        ubuntu:14.04.1
MAINTAINER  Dennis Micky Jensen "root@mewm.org"

RUN apt-get update -qq && apt-get upgrade -yqq
RUN apt-get -yqq install varnish
RUN apt-get -yqq clean

ADD start.sh /start.sh
