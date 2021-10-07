#!/bin/bash

MYSQL_UNAME=$(cat ~/as_configs/.db_user)
MYSQL_PWORD=$(cat ~/as_configs/.db_auth)
# SCHEMA=automation_suite
# REF_TABLE=job_execution_log

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

function __display_help()
{
   # Display Help
   echo "
DESCRIPTION:
  MySQL helper script to set ON DELETE CASCADE for all child tables of a reference table provided by argument -r=*.

SYNTAX:
  fk_cascade.sh -s=* -r=*

OPTIONS:
  --schema=*, -s=*   Databse Schema (required)
  --ref=*, -r=*      Reference Table (required)
  --help             Display help page (optional)";
  echo;
}

while [ $# -gt 0 ]; do
  case "$1" in
    -s=* | --schema=*)
      SCHEMA="${1#*=}"
      ;;
    -r=* | --ref=*)
      REF_TABLE="${1#*=}"
      ;;
    --help)
      __display_help;
      exit 0;
      ;;
    *)
      printf "$(date '+%Y-%m-%d %H:%M:%S') [ERR] Error: Invalid argument. $1 Printing help page\n\n";
      __display_help;
      exit 1
  esac
  shift
done

[[ -z "$SCHEMA" ]] && MISSING_PARAMETER="argument [-s=* | --schema=*]";
[[ -z "$REF_TABLE" ]] && MISSING_PARAMETER="argument [-r=* | --ref=*]";

if [[ ! -z "$MISSING_PARAMETER" ]]; then
  echo "ERROR: $MISSING_PARAMETER not supplied to script. Printing help page";
  __display_help;
  exit 1;
fi

mysql --defaults-extra-file=$CREDENTIALSFILE -e "SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE table_schema = 'automation_suite' AND referenced_table_name = '$REF_TABLE';" | while read CONSTRAINT_NAME TABLE_NAME COLUMN_NAME REFERENCED_TABLE_NAME REFERENCED_COLUMN_NAME; do
  if [[ "$CONSTRAINT_NAME" != 'CONSTRAINT_NAME' ]]; then
    echo "C: $CONSTRAINT_NAME, TBL: $TABLE_NAME, COL: $COLUMN_NAME REF_TBL: $REFERENCED_TABLE_NAME REF_COL: $REFERENCED_COLUMN_NAME"

    mysql --defaults-extra-file=$CREDENTIALSFILE -e "ALTER TABLE $SCHEMA.$TABLE_NAME DROP FOREIGN KEY $CONSTRAINT_NAME"
    mysql --defaults-extra-file=$CREDENTIALSFILE -e "ALTER TABLE $SCHEMA.$TABLE_NAME ADD CONSTRAINT $CONSTRAINT_NAME FOREIGN KEY ($COLUMN_NAME) REFERENCES $SCHEMA.$REFERENCED_TABLE_NAME ($REFERENCED_COLUMN_NAME) ON DELETE CASCADE;"
    mysql --defaults-extra-file=$CREDENTIALSFILE -e "ALTER TABLE $SCHEMA.$TABLE_NAME ENGINE=InnoDB;"

  fi
done
