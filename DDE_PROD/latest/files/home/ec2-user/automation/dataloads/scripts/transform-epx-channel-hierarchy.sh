#!/bin/bash
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log

}

cd ~/automation/dataloads/scripts

logger "Start cleaning non-printable characters and trim blanks" 

cat data/extracted_dealer_channel.dat |  perl -pe 's/[^\x20-\x7E\x0A]//g' | awk -F'|' '{ for (i=1; i<=NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) } OFS="|"; print }'|awk -F'|' '{ gsub(/[^|]+/, "\"&\""); OFS="|"; print }' > data/cleaned_dealer_channel.csv 
cat data/extracted_dealer_sub_channel.dat |  perl -pe 's/[^\x20-\x7E\x0A]//g' | awk -F'|' '{ for (i=1; i<=NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) } OFS="|"; print }'|awk -F'|' '{ gsub(/[^|]+/, "\"&\""); OFS="|"; print }' > data/cleaned_dealer_sub_channel.csv 
cat data/extracted_dealer_group.dat |  perl -pe 's/[^\x20-\x7E\x0A]//g' | awk -F'|' '{ for (i=1; i<=NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) } OFS="|"; print }'|awk -F'|' '{ gsub(/[^|]+/, "\"&\""); OFS="|"; print }' > data/cleaned_dealer_group.csv 
cat data/extracted_dealer_master.dat |  perl -pe 's/[^\x20-\x7E\x0A]//g' | awk -F'|' '{ for (i=1; i<=NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) } OFS="|"; print }'|awk -F'|' '{ gsub(/[^|]+/, "\"&\""); OFS="|"; print }' > data/cleaned_dealer_master.csv 

rc=$?

if (( $rc == 0 ));then
   logger "	Successful transformation" 
else
   logger "	Error during transformation" 
   exit $rc
fi
