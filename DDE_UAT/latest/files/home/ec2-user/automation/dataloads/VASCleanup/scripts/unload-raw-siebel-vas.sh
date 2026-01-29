#!/bin/bash
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log
}

logger "===========================START================================================"
logger "Update Eppix connection information"
logger "Running script: $(basename $0)"
logger "Initiate Siebel unload"

sqlplus /nolog @sql/test.sql >/dev/null 2>/dev/null
rc=$?

if [ $rc -eq 0 ];then
   CNT=$(cat data/siebel_vas_extract.dat | wc -l)
   logger "	Successful Siebel unload: $CNT" 
else
   logger "	Error during Siebel login or unload" 
   exit $rc 
fi

