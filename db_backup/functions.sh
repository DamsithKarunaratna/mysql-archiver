#!/bin/bash

# [$1 LOG_LVL] [$2 MESSAGE]
function __log() {
  if [[ "$1" == 'ERR' ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] Error in $0";
  fi;
  case "$LOG_LVL" in
    DBG)
      [[ "$1" =~ ^(INF|ERR|DBG)$ ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2";
      ;;
    INF)
      [[ "$1" =~ ^(INF|ERR)$ ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2";
      ;;
    ERR)
      [[ "$1" =~ ^(ERR)$ ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2";
      ;;
  esac
}

# [$1 LOG_LVL] [$2 MESSAGE]
function __log_progress() {
  echo -en "\r$(date '+%Y-%m-%d %H:%M:%S') [$1] $2";
}

# [$1 SOURCE_SCHEMA] [$2 DEST_SCHEMA] [$3 REF_TABLE]
function __diff_schemas() {
  __log 'INF' "Checking if databases exist ['$1' , '$2'] ";
  SCHEMA_CHECK_COUNT=$(mysql --defaults-extra-file=$CREDENTIALSFILE -N -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME IN ('$1', '$2');");
  if [[ "$SCHEMA_CHECK_COUNT" != '2' ]]; then 
    __log 'ERR' "Please check if '$1' and '$2' are valid schemas";
    exit 1; 
  fi;

  RESULT_COUNT=$(mysql --defaults-extra-file=$CREDENTIALSFILE -N -e "
    SELECT COUNT(*) FROM (
			SELECT table_schema, table_name, column_name,ordinal_position, data_type, column_type, COUNT(1) rowcount
			FROM information_schema.columns
			WHERE (
				((table_schema='$1') OR (table_schema='$2'))
				AND (
					table_name = '$3' 
          OR table_name IN (
					 	SELECT TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE table_schema IN ('$1', '$2') AND referenced_table_name = '$3'
					)
				)
			)
			GROUP BY column_name,ordinal_position, data_type,column_type
			HAVING COUNT(1)=1
		) A;
  ");

  if [[ "$RESULT_COUNT" != '0' ]]; then 
    RESULT=$(mysql --defaults-extra-file=$CREDENTIALSFILE -e "
      SELECT table_schema, table_name, column_name,ordinal_position,data_type,column_type FROM (
      SELECT table_schema, table_name, column_name,ordinal_position, data_type, column_type, COUNT(1) rowcount
      FROM information_schema.columns
      WHERE (
        ((table_schema='$1') OR (table_schema='$2'))
        AND (
          table_name  = '$3'
          OR table_name IN (
            SELECT TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE table_schema IN ('$1', '$2') AND referenced_table_name  = '$3'
          )
        )
      )
      GROUP BY column_name,ordinal_position, data_type,column_type
      HAVING COUNT(1)=1
    ) A;
  ");
    __log 'ERR' "The script detected $RESULT_COUNT differences between schemas '$1' & '$2'";  
    printf "\n$RESULT\n\n";
    exit 1; 
  fi;
}

# [$1 SOURCE_SCHEMA] [$2 DEST_SCHEMA] [$3 REF_TABLE] [$4 WHERE_CLAUSE]
function __archive_data_selectively() {
  INS_COUNT=$(mysql --defaults-extra-file=$CREDENTIALSFILE -N -e "REPLACE INTO $2.$3 SELECT * FROM $1.$3 WHERE $4; SELECT ROW_COUNT();");
  if [[ "$?" -ne "0" ]]; then
    exit 1;
  fi
  __log 'INF' "Backed up [$1.$3] ($INS_COUNT rows affected)";
  mysql --defaults-extra-file=$CREDENTIALSFILE -e "SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE table_schema = '$1' AND referenced_table_name = '$3';" | while read TABLE_NAME COLUMN_NAME REFERENCED_COLUMN_NAME; do
    if [[ "$TABLE_NAME" != 'TABLE_NAME' ]]; then  
      INSERTED_ROW_COUNT=$(mysql --defaults-extra-file=$CREDENTIALSFILE -N -e "SET foreign_key_checks = 0; INSERT INTO $2.$TABLE_NAME SELECT * FROM $1.$TABLE_NAME WHERE $COLUMN_NAME IN (SELECT $REFERENCED_COLUMN_NAME FROM $1.$3 WHERE $4) ON DUPLICATE KEY UPDATE $2.$TABLE_NAME.$COLUMN_NAME=$2.$TABLE_NAME.$COLUMN_NAME; SELECT ROW_COUNT();");
      exit_status=$?
      if [[ "$exit_status" -ne "0" ]]; then
        exit 1;
      fi
      __log 'INF' "Backed up [$TABLE_NAME.$COLUMN_NAME] ($INSERTED_ROW_COUNT rows affected)";
    fi
  done

  if [[ "$?" -ne "0" ]]; then
    __log 'ERR' "Error in __archive_data_selectively()";
    exit 1;
  fi
}

# [$1 SOURCE_SCHEMA] [$2 REF_TABLE] [$3 WHERE_CLAUSE] [$4 DEL_BATCH_SIZE]
function __mysql_limited_delete() {
  DELETED_ROW_COUNT=$(mysql --defaults-extra-file=$CREDENTIALSFILE -N -e "DELETE FROM $1.$2 WHERE $3 LIMIT $4; SELECT ROW_COUNT();");
  echo "$DELETED_ROW_COUNT"
}

# [$1 SOURCE_SCHEMA] [$2 REF_TABLE] [$3 WHERE_CLAUSE] [$4 DEL_BATCH_SIZE] [$5 LOOP_SLEEP]
function __liimited_recursive_delete() {
  TOT=0;
  while [[ true ]]
    DELETED=$(__mysql_limited_delete "$1" "$2" "$3" "$4");
    TOT=$(($TOT+$DELETED));
    __log_progress 'INF' "__liimited_recursive_delete($1.$2) ($TOT/$INS_COUNT rows deleted)";
    if [[ $DELETED == '0' ]]; then break; fi;
    sleep $5
  do true; done
  echo;
}