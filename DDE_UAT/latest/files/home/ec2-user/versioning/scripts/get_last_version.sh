#!/bin/bash

WEEKDAY_TODAY=$(date +%u)
DATE_PREV=$(date -d 'yesterday' +%Y-%m-%d)
MONTH_DATE=$(date +%m_%Y)

if [[ $WEEKDAY_TODAY -eq '1' ]]; then
	DATE_PREV=$(date -d 'last friday' +%Y-%m-%d)
fi

if [[ $1 -eq '1' ]]; then
	filename="software_versioning_$MONTH_DATE.txt"
else
	filename="proc_versioning_$MONTH_DATE.txt"
fi

cat ~/versioning/scripts/$filename | grep $DATE_PREV | grep $2
