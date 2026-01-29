#!/bin/bash
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log
}

logger "===========================START================================================"
logger "Running script: unload-raw-infinity-vas.sh"
logger "Initiate Infinity unload"

sqlplus /nolog @sql/unload_siebel_vas.sql >/dev/null 2>/dev/null
rc=$?
#test fail
#rc=123456789

if [ $rc -eq 0 ];then
   CNT=$(cat data/siebel_vas_extract.dat | wc -l)
   logger "	Successful Infinity unload: $CNT" 
else
   logger "	Error during Infinity login or unload" 
   exit $rc 
fi

