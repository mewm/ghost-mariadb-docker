#!/bin/sh

script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );

if [ "$1" = "db" ]; then
	echo "Creating database backup ${2}"
	docker run --volumes-from ghostmariadbdocker_data_1 -v ${script_dir}/../backups:/backups ubuntu tar cvf /backups/$2 /var/lib/mysql
elif [ "$1" = "ghost" ]; then
	echo "Creating ghost backup ${2}"
	docker run --volumes-from ghostmariadbdocker_data_1 -v ${script_dir}/../backups:/backups ubuntu tar cvf /backups/$2 /var/www/ghost/content 
else
	echo "Usage: sh create_bacup.sh db|ghost file.tar"
fi

