#!/bin/bash


aws rds describe-db-instances | jq '.DBInstances[] | {DBInstanceIdentifier, DBInstanceClass, DBInstanceStatus, EngineVersion, Endpoint: .Endpoint.Address}' | sed "s/\"//g" | sed "s/,//g" | grep ":" > $$temp1
cat $$temp1 | egrep "DBInstanceIdentifier|DBInstanceClass|DBInstanceStatus|Endpoint|EngineVersion" | awk -F ":" '{a=$2;getline;b=$2;getline;c=$2;getline;d=$2;getline;e=$2;print a,b,c,d,e}' > $$temp3


p="reader writer"

#echo "Check for RDS node role switch"
#echo "=============================="
for i in $p
do
  cnt=$(cat $$temp3 | grep $i | wc -l)
  if (( $cnt > 1 ));then
    echo $i"_state switch_detected"
  else
    echo $i"_state normal"
  fi
done

rm $$temp1 $$temp3

