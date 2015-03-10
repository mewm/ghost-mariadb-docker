#!/bin/sh

app_dir="/var/www/ghost-mariadb-docker";

if [ "$1" = "db" ]; then
	echo "Restoring database backup ${2}"
	docker run --volumes-from ghostmariadbdocker_data_1 -v "${app_dir}/backups":"/backups" ubuntu tar xvf /backups/$2
elif [ "$1" = "ghost" ]; then
	echo "Restoring ghost backup ${2}"
	docker run --volumes-from ghostmariadbdocker_data_1 -v "${app_dir}/backups":"/backups" ubuntu tar xvf /backups/$2
else
	echo "Usage: sh restore_bacup.sh db|ghost file.tar"
fi
#(date +%Y_%m_%d)

