#!/bin/bash
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log

}

cd ~/automation/dataloads/scripts

logger "Start cleaning non-printable characters and trim blanks" 

cat data/extracted_vpk_package.dat |  perl -pe 's/[^\x20-\x7E\x0A]//g' | awk -F'|' '{ for (i=1; i<=NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) } OFS="|"; print }'|awk -F'|' '{ gsub(/[^|]+/, "\"&\""); OFS="|"; print }' > data/cleaned_vpk_package.csv 

rc=$?

if (( $rc == 0 ));then
   logger "	Successful transformation" 
else
   logger "	Error during transformation" 
   exit $rc
fi
