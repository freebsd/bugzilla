#!/bin/sh

PATH=$PATH:/usr/local/bin

# Path to save the files to
BACKUPPATH="/var/backup/bugzilla"

# DB to save
DBNAME="<DBNAME>"

# DB user
DBUSER="<DBUSER>"

# Keep backups for how long?
KEEPFOR="14d"

# File to 
BACKUPFILE="$DBNAME-`date +\%Y-\%m-\%d-\%H_\%M_\%S`.backup"

if [ ! -d $BACKUPPATH ]; then
	echo "[ERROR]: path $BACKUPPATH for storing the backup files does not exist" 1>&2
	exit 1;
fi

pg_dump --format=c --compress=5 -f $BACKUPPATH/$BACKUPFILE -U $DBUSER $DBNAME

if [ $? -ne 0 ]; then
	echo "[ERROR]: creating a backup for $DBNAME to $BACKUPFILE failed!" 1>&2
	exit 1;
fi

find $BACKUPPATH -maxdepth 1 -mtime +$KEEPFOR -name "$DBNAME-*" -exec rm -f '{}' ';'

