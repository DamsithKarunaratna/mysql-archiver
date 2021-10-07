#!/bin/bash

MYSQL_UNAME=$(cat ~/as_configs/.db_user)
MYSQL_PWORD=$(cat ~/as_configs/.db_auth)

CREDENTIALSFILE=/home/automation/mysql-credentials.cnf;
echo "[client]" > $CREDENTIALSFILE;
echo "user=$MYSQL_UNAME" >> $CREDENTIALSFILE;
echo "password=$MYSQL_PWORD" >> $CREDENTIALSFILE;

function __cleanup() {
  exit_code=$?;
  rm $CREDENTIALSFILE;
  printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] Cleanup complete. Exited with code $exit_code \n\n";
}

trap __cleanup EXIT;

while [ $# -gt 0 ]; do
  case "$1" in
    -s=* | --schema=*)
      SCHEMA="${1#*=}"
      ;;
    -r=* | --ref=*)
      REF_TABLE="${1#*=}"
      ;;
    *)
      printf "$(date '+%Y-%m-%d %H:%M:%S') [ERR] Error: Invalid argument. $1\n\n";
      exit 1
  esac
  shift
done

[[ -z "$SCHEMA" ]] && MISSING_PARAMETER="argument [-s=* | --schema=*]";
[[ -z "$REF_TABLE" ]] && MISSING_PARAMETER="argument [-r=* | --ref=*]";

if [[ ! -z "$MISSING_PARAMETER" ]]; then
  echo "ERROR: $MISSING_PARAMETER not supplied to script";
  exit 1;
fi

printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] STARTING OPTIMIZER SCRIPT \n";
printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] Optimizing $SCHEMA.$REF_TABLE \n";

mysql --defaults-extra-file=$CREDENTIALSFILE -e "ALTER TABLE $SCHEMA.$REF_TABLE ENGINE=InnoDB;";

mysql --defaults-extra-file=$CREDENTIALSFILE -e "SELECT DISTINCT TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE table_schema = '$SCHEMA' AND referenced_table_name = '$REF_TABLE';" | while read TABLE_NAME; do
  if [[ "$TABLE_NAME" != 'TABLE_NAME' ]]; then
    printf "$(date '+%Y-%m-%d %H:%M:%S') [INF] Optimizing $TABLE_NAME \n";
    mysql --defaults-extra-file=$CREDENTIALSFILE -e "ALTER TABLE $SCHEMA.$TABLE_NAME ENGINE=InnoDB;";
  fi
done
