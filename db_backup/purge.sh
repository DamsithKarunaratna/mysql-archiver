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
  MySQL Database purge script. Deletes data in batches recursively.

SYNTAX: 
  backup.sh -s=* -d=* -r=* -w=* [-b=*] [-p=*] [--purge=true]

OPTIONS:
  --source=*, -s=*   Source schema (required)
  --ref=*, -r=*      Reference Table (required)
  --where=*, -w=*    Where clause for reference table (required)
  --batch=*, -b=*    Batch size for recursive delete (optional, default = 100)
  --pause=*, -p=*    Pause (in seconds) after each delete (optional, default = 2)
  --help             Display help page (optional)";
  echo;
}

while [ $# -gt 0 ]; do
  case "$1" in
    -s=* | --source=*)
      SOURCE_SCHEMA="${1#*=}"
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
[[ -z "$REF_TABLE" ]] && MISSING_PARAMETER="argument [-r=* | --ref=*]";
[[ -z "$WHERE_CLAUSE" ]] && MISSING_PARAMETER="argument [-w=* | --where=*]";

if [[ ! -z "$MISSING_PARAMETER" ]]; then
  __log 'ERR' "$MISSING_PARAMETER not supplied to script. Printing help page";
  __display_help;
  exit 1;
fi

printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] STARTING PURGE SCRIPT \n";
printf "$(date '+%Y-%m-%d %H:%M:%S') [SYS] Purging $SOURCE_SCHEMA.$REF_TABLE \n";

__log 'INF' "--purge flag detected. deleting rows";
__liimited_recursive_delete "$SOURCE_SCHEMA" "$REF_TABLE" "$WHERE_CLAUSE" "$DEL_BATCH_SIZE" "$LOOP_SLEEP";

exit 0;
