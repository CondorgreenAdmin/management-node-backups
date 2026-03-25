#!/bin/bash
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log

}

logger "Start cleaning non-printable characters and trim blanks" 

cat data/siebel_vas_extract.dat |  perl -pe 's/[^\x20-\x7E\x0A]//g' | awk -F'|' '{ for (i=1; i<=NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) } OFS="|"; print }'|awk -F'|' '{ gsub(/[^|]+/, "\"&\""); OFS="|"; print }' > data/siebel_vas_cleaned.csv 

rc=$?

if (( $rc == 0 ));then
   logger "	Successful transformation" 
else
   logger "	Error during transformation" 
   exit $rc
fi
