Script "fk_cascade"
=============

To ensure that the backup script works properly, all child tables connected to the ref_table need to have ON DELETE CASCADE set for their foreign keys.
This enables us to delete all related child rows by deleting just the parent record.

The fk_cascade script can be used to set ON DELETE CASCADE for all foreign keys pointing to the reference table.

usage
-------------

- ./fk_cascade.sh -s=automation_suite -r=job_execution_log
- ./fk_cascade.sh -s=automation_suite -r=service_notification_message

| ARGUMENT      | DESCRIPTION     | REQUIRED | DEFAULT |
|---------------|-----------------|----------|---------|
| -s , --schema | Source schema   | yes      | -       |
| -r , --ref    | Reference Table | yes      | -       |

  
<p>&nbsp;</p>

Script "backup"
=============
The main script that contains the backup logic.

1. Uses __diff_schemas to check for differences between the source and destination schemas.
2. Uses __archive_data_selectively to insert parent records and all related child records from the source reference table.
3. Uses __liimited_recursive_delete to empty all the backed up records from the source schema.

 
usage
-------------

- ./backup.sh -s=automation_suite -d=automation_suite_archive -r=job_execution_log -w="created_on BETWEEN '2020-04-30 00:00:00' AND '2020-05-01 00:00:00'" --purge=true


| ARGUMENT      | DESCRIPTION                          | REQUIRED | DEFAULT |
|---------------|--------------------------------------|----------|---------|
| -s , --source | Source schema                        | yes      | -       |
| -d , --dest   | Destination schema                   | yes      | -       |
| -r , --ref    | Reference Table                      | yes      | -       |
| -w , --where  | Where clause for reference table     | yes      | -       |
| -b , --batch  | Batch size for recursive delete      | no       | 100     |
| -p , --pause  | Pause (in seconds) after each delete | no       | 2       |
| --purge       | Purge data from referece table       | no       | false   |


e.g. delete 6 months old data 

