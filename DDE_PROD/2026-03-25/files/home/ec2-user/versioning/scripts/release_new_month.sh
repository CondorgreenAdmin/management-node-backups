#!/bin/bash

# its the first of the month
DATE_LAST_MONTH="$(date -d 'last month' +%m_%Y)"
FILENAME_SOFTWARE_LAST_MONTH="software_versioning_${DATE_LAST_MONTH}.txt"
SOFTWARE_LAST_MONTH_ENTRY="$(cat ~/versioning/scripts/${FILENAME_SOFTWARE_LAST_MONTH} | tail -4)"

# move the last entry from last month to the new months file
DATE_NEW_MONTH="$(date +%m_%Y)"
FILENAME_SOFTWARE_NEW_MONTH="software_versioning_${DATE_NEW_MONTH}.txt"

cat $SOFTWARE_LAST_MONTH_ENTRY > ~/versioning/scripts/${FILENAME_SOFTWARE_NEW_MONTH}
