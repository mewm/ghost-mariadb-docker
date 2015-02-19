#!/bin/bash

VOLUME_HOME="/var/lib/mysql"
if find ${VOLUME_HOME} -maxdepth 0 -empty | read v; then
    echo " -> Installation detected in $VOLUME_HOME"
    echo " -> Installing MariaDB"
    mysql_install_db > /dev/null 2>&1
    echo " -> Done!"
    /create-mariadb-user.sh
else
    echo "-> Booting on existing volume!"
fi

exec mysqld_safe