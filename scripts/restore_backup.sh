#!/bin/sh
if [ "$1" = "db" ]; then
	echo "Restoring database backup ${2}"
	docker run --volumes-from ghostmariadbfig_data_1 -v $(pwd)/../backups:/backups ubuntu tar xvf /backups/$2
elif [ "$1" = "ghost" ]; then
	echo "Restoring ghost backup ${2}"
	docker run --volumes-from ghostmariadbfig_data_1 -v $(pwd)/../backups:/backups ubuntu tar xvf /backups/$2
else
	echo "Usage: sh restore_bacup.sh db|ghost file.tar"
fi
#(date +%Y_%m_%d)

