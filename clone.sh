#!/bin/bash

MYSQL_UNAME=$(cat ~/as_configs/.db_user)
MYSQL_PWORD=$(cat ~/as_configs/.db_auth)
CREDENTIALSFILE=/home/$(whoami)/mysql-credentials.cnf;

echo "[client]" > $CREDENTIALSFILE;
echo "user=$MYSQL_UNAME" >> $CREDENTIALSFILE;
echo "password=$MYSQL_PWORD" >> $CREDENTIALSFILE;

function __cleanup() {
  exit_code=$?;
  rm $CREDENTIALSFILE;
  printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] Cleanup complete. Exited with code $exit_code \n\n";
}

trap __cleanup EXIT;

# CHECK FOR AND CREATE ARCHIVE DB 
mysql --defaults-extra-file=$CREDENTIALSFILE -e "CREATE DATABASE IF NOT EXISTS automation_suite_archive";
mysqldump --defaults-extra-file=$CREDENTIALSFILE --no-data --set-gtid-purged=OFF automation_suite | mysql --defaults-extra-file=$CREDENTIALSFILE automation_suite_archive

