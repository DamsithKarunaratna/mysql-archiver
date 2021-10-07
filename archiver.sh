#!/bin/bash

# [$1 = $?] [$2 = $LINENO]
function __check_for_command_failure() {
  if [[ "$1" -ne "0" ]]; then
  printf "$(date '+%Y-%m-%d %H:%M:%S') [ERR] Script failure in $0 Line $2. See output above \n\n";
  exit 1;
fi
}

echo "
==========================================================================
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░████░░░░░██▀███░░░░▄████▄░░░░██░░██░░░██░░░██▒░░░█░░░█████░░░██▀███░░
▒░██████░░░▓██░▒░██░░▒██▀░▀█░░░▓██░░██░░▓██░░░██░░░░█▒░▓█░░░▀░░▓██░▒░██▒
▒██░░░░██░░▓██░░▄█░░░▒▓█░░░░▄░░▓██▀▀██░░▓██░░░▓██░░█▒░░████░░░░▓██░░▄█░▒
░██▄▄▄▄██░░▓██▀▀█▄░░░▒▓▓▄░▄██▒░▓██░░██░░▓██░░░░▒██░█░░░▓██░░▄░░▓██▀▀█▄░░
░▓█░░░░██▒░▓██░░▒██░░▒░▓███▀░░░▓██▒░██░░▓██░░░░░▒▀█░░░▒██████▒░▓██▓░▒██▒
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░ Wiley Service Automation Team ░░░░░░░░░░░░░░░░░░
===========================================================================
";

while [ $# -gt 0 ]; do
  case "$1" in
    -m=* | --months=*)
      MONTHS_TO_KEEP="${1#*=}"
      ;;
    *)
      echo "$(date '+%Y-%m-%d %H:%M:%S') [ERR] Invalid argument $1";
      __display_help;
      exit 1
  esac
  shift
done

[[ -z "$MONTHS_TO_KEEP" ]] && MISSING_PARAMETER="argument [-m=* | --months=*]";

if [[ ! -z "$MISSING_PARAMETER" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERR] $MISSING_PARAMETER not supplied to script";
  exit 1;
fi

EXEC_BACKUP=/opt/automation/projects/database_scripts/db_backup/backup.sh;
EXEC_OPTIMIZE=/opt/automation/projects/database_scripts/optimize.sh;

# STEP 1 BACKUP
$EXEC_BACKUP -s=automation_suite -d=automation_suite_archive -r=job_execution_log -w="created_on < CURRENT_DATE - INTERVAL $MONTHS_TO_KEEP MONTH" --purge;
__check_for_command_failure "$?" "$LINENO";

$EXEC_BACKUP -s=automation_suite -d=automation_suite_archive -r=service_notification_message -w="created_on < CURRENT_DATE - INTERVAL $MONTHS_TO_KEEP MONTH" --purge;
__check_for_command_failure "$?" "$LINENO";

# STEP 2 OPTIMIZE
$EXEC_OPTIMIZE -s=automation_suite_archive -r=job_execution_log;
__check_for_command_failure "$?" "$LINENO";

$EXEC_OPTIMIZE -s=automation_suite_archive -r=service_notification_message;
__check_for_command_failure "$?" "$LINENO";

# /opt/automation/projects/database_scripts/db_backup/backup.sh -s=automation_suite_archive -d=automation_suite -r=job_execution_log -w="created_on < CURRENT_DATE - INTERVAL $MONTHS_TO_KEEP MONTH";
# __check_for_command_failure "$?" "$LINENO";

# /opt/automation/projects/database_scripts/db_backup/backup.sh -s=automation_suite_archive -d=automation_suite -r=service_notification_message -w="created_on < CURRENT_DATE - INTERVAL $MONTHS_TO_KEEP MONTH";
# __check_for_command_failure "$?" "$LINENO";
