#!/bin/bash
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log
}

cd ~/automation/dataloads/scripts

logger "===========================START================================================"
logger "Update Eppix connection information"
logger "Running script: $(basename $0)"
~/decode-secret.sh eppix-secret default >> $$_temp

srv=$(cat $$_temp | grep host: | awk '{print $2}')
pss=$(cat $$_temp | grep pass: | awk '{print $2}')
usr=$(cat $$_temp | grep user: | awk '{print $2}')

echo "machine $srv" > ~/.netrc
echo "password $pss" >> ~/.netrc
echo "login $usr" >> ~/.netrc

rm $$_temp

logger "Initiate Eppix unload"

dbaccess eppix sql/unload_vpk_package.sql >/dev/null 2>/dev/null
rc=$?

#dbaccess eppix sql/unload_vpk_package.sql >> logs/status.log 2>>logs/status.log

if [ $rc -eq 0 ];then
   CNT=$(cat data/extracted_vpk_package.dat | wc -l)
   logger "	Successful Eppix unload: $CNT" 
else
   logger "	Error during Eppix login or unload" 
   exit $rc 
fi

