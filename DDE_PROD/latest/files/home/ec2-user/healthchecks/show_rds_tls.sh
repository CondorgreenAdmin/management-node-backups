#!/bin/bash

export PATH=/usr/local/bin:$PATH

aws rds describe-db-instances | egrep "DBInstanceIdentifier|CAIdentifier|ValidTill" | sed "s/\"//g" | sed "s/\,//g" | awk '{nam=$2;getline;getline;ca=$2;getline;v=$2;print nam,ca,v}' > $$_rds_tls

ts_today=$(date +%s)

while read a b c
do
  notAfter=$(date -d "$c" +%s)
  days=$(( notAfter - ts_today ))
  days=$(( days / 86400 ))
  echo $a $b $c $days
done<$$_rds_tls


#ts_notAfter=$(date -d "$notAfter" +%s)

#diff=$((ts_notAfter - ts_notBefore))
#days=$((diff / 86400))

#s_notBefore=$(echo $notBefore | sed "s/ /#/g")
#s_notAfter=$(echo $notAfter | sed "s/ /#/g")

#echo "$s_notBefore   $s_notAfter   $days"

rm $$_rds_tls






#            DBInstanceIdentifier: prd-dde-reader
#            ReadReplicaDBInstanceIdentifiers: []
#                CAIdentifier: rds-ca-rsa2048-g1
#                ValidTill: 2025-07-17T09:45:39+00:00
#            DBInstanceIdentifier: prd-dde-writer
#            ReadReplicaDBInstanceIdentifiers: []
#                CAIdentifier: rds-ca-rsa2048-g1
#                ValidTill: 2025-07-17T09:48:23+00:00

