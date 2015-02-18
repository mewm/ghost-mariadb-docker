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