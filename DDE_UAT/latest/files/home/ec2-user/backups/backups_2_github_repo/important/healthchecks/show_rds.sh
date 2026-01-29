#!/bin/bash

#aws rds describe-db-instances | jq '.DBInstances[] | {DBInstanceIdentifier, DBInstanceClass, DBInstanceStatus, Endpoint: .Endpoint.Address}' | sed "s/\"//g" | sed "s/,//g" > $$temp1

aws rds describe-db-instances | jq '.DBInstances[] | {DBInstanceIdentifier, DBInstanceClass, DBInstanceStatus, EngineVersion, Endpoint: .Endpoint.Address}' | sed "s/\"//g" | sed "s/,//g" | grep ":" > $$temp1
cat $$temp1 | egrep "DBInstanceIdentifier|DBInstanceClass|DBInstanceStatus|Endpoint|EngineVersion" | awk -F ":" '{a=$2;getline;b=$2;getline;c=$2;getline;d=$2;getline;e=$2;print a,b,c,d,e}' > $$temp3


p="reader writer"

#echo "Check for RDS node status"
#echo "========================="
for i in $p
do
  lne=$(cat $$temp3 | grep $i)
  nam=$(echo $lne | awk '{print $1}')
  sze=$(echo $lne | awk '{print $2}')
  sta=$(echo $lne | awk '{print $3}')
  ver=$(echo $lne | awk '{print $4}')
  echo "$nam $sze $ver $sta"
done

rm $$temp1 $$temp3

