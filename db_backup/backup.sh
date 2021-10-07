#!/bin/bash

unset MISSING_PARAMETER
LOG_LVL=INF;
DEL_BATCH_SIZE=1000;
LOOP_SLEEP=2;
PURGE=false;
CREDENTIALS_SHELL_SCRIPT="$(dirname "$0")/credentials.sh";
FUNCTIONS_SHELL_SCRIPT="$(dirname "$0")/functions.sh";

if [[ ! -f $CREDENTIALS_SHELL_SCRIPT || ! -f $FUNCTIONS_SHELL_SCRIPT ]] ; then
    printf "$(date '+%Y-%m-%d %H:%M:%S') [ERR] Sourcing CREDENTIALS_SHELL_SCRIPT or FUNCTIONS_SHELL_SCRIPT failed, aborting $0\n\n";
    exit 1;
fi

# MYSQL credentials stored in variable $CREDENTIALSFILE 
source $CREDENTIALS_SHELL_SCRIPT;
source $FUNCTIONS_SHELL_SCRIPT;

function __display_help()
{
   echo "
DESCRIPTION: 
  MySQL Database archival script. Replicates data into a secondary schema

SYNTAX: 
  backup.sh -s=* -d=* -r=* -w=* [-b=*] [-p=*] [--purge=true]

OPTIONS:
  --source=*, -s=*   Source schema (required)
  --dest=*, -d=*     Destination schema (required)
  --ref=*, -r=*      Reference Table (required)
  --where=*, -w=*    Where clause for reference table (required)
  --batch=*, -b=*    Batch size for recursive delete (optional, default = 100)
  --pause=*, -p=*    Pause (in seconds) after each delete (optional, default = 2)
  --purge=true       Purge data from reference table (optional, default = false)
  --help             Display help page (optional)";
  echo;
}

while [ $# -gt 0 ]; do
  case "$1" in
    -s=* | --source=*)
      SOURCE_SCHEMA="${1#*=}"
      ;;
    -d=* | --dest=*)
      DEST_SCHEMA="${1#*=}"
      ;;
    -r=* | --ref=*)
      REF_TABLE="${1#*=}"
      ;;
    -w=* | --where=*)
      WHERE_CLAUSE="${1#*=}"
      ;;
    -b=* | --batch=*)
      DEL_BATCH_SIZE="${1#*=}"
      ;;
    -p=* | --pause=*)
      LOOP_SLEEP="${1#*=}"
      ;;
    --purge)
      PURGE=true
      ;;
    --help)
      __display_help;
      exit 0;
      ;;
    *)
      __log 'ERR' "Invalid argument $1. Printing help page";
      __display_help;
      exit 1
  esac
  shift
done

[[ -z "$SOURCE_SCHEMA" ]] && MISSING_PARAMETER="argument [-s=* | --source=*]";
[[ -z "$DEST_SCHEMA" ]] && MISSING_PARAMETER="argument [-d=* | --dest=*]";
[[ -z "$REF_TABLE" ]] && MISSING_PARAMETER="argument [-r=* | --ref=*]";
[[ -z "$WHERE_CLAUSE" ]] && MISSING_PARAMETER="argument [-w=* | --where=*]";

if [[ ! -z "$MISSING_PARAMETER" ]]; then
  __log 'ERR' "$MISSING_PARAMETER not supplied to script. Printing help page";
  __display_help;
  exit 1;
fi

# CHECK FOR AND CREATE ARCHIVE DB 
# mysql --defaults-extra-file=$CREDENTIALSFILE -e "CREATE DATABASE IF NOT EXISTS automation_suite_archive";
# mysqldump --defaults-extra-file=$CREDENTIALSFILE --no-data --set-gtid-purged=OFF automation_suite | mysql --defaults-extra-file=$CREDENTIALSFILE automation_suite_archive

printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] STARTING BACKUP SCRIPT \n";
printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] Archiving $SOURCE_SCHEMA.$REF_TABLE \n";

__log 'INF' "Checking for differences in archive and source databases";
__diff_schemas "$SOURCE_SCHEMA" "$DEST_SCHEMA" "$REF_TABLE";

__log 'INF' "Inserting data into archive database";
__archive_data_selectively "$SOURCE_SCHEMA" "$DEST_SCHEMA" "$REF_TABLE" "$WHERE_CLAUSE";

if [[ "$PURGE" == 'false' ]]; then  
  __log 'INF' "--purge flag not detected, skipping deletion";
else
  __log 'INF' "--purge flag detected. deleting original rows";
  __liimited_recursive_delete "$SOURCE_SCHEMA" "$REF_TABLE" "$WHERE_CLAUSE" "$DEL_BATCH_SIZE" "$LOOP_SLEEP";
fi

exit 0;
