#!/bin/bash

# Go to working directory
cd ~/versioning/scripts

# its the first of the month
DATE_LAST_MONTH=$(date -d 'last month' +%m_%Y)
FILENAME_SOFTWARE_LAST_MONTH="software_versioning_$DATE_LAST_MONTH.txt"
FILENAME_PROC_LAST_MONTH="proc_versioning_$DATE_LAST_MONTH.txt"

# move the last entry from last month to the new months file
DATE_NEW_MONTH=$(date +%m_%Y)
FILENAME_SOFTWARE_NEW_MONTH="software_versioning_$DATE_NEW_MONTH.txt"
FILENAME_PROC_NEW_MONTH="proc_versioning_$DATE_NEW_MONTH.txt"

tail -n 4 $FILENAME_SOFTWARE_LAST_MONTH > $FILENAME_SOFTWARE_NEW_MONTH
tail -n 1 $FILENAME_PROC_LAST_MONTH > $FILENAME_PROC_NEW_MONTH
