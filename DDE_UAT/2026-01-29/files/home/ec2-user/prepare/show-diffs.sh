#!/usr/bin/bash

TODO=$(./create-uat-list.sh|grep maintenance|egrep -v "campaign|siebel|adhoc")


for nam in $TODO
do
   echo "========================== START  $nam  ================================================"
   diff -u -w -B uat_$nam dev_$nam
   echo "=========================  END  ========================================================"
   echo
done


