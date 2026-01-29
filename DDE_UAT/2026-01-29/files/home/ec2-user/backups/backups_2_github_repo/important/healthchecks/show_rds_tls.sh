#!/bin/bash

aws rds describe-db-instances | egrep "DBInstanceIdentifier|CAIdentifier|ValidTill" | sed "s/\"//g" | sed "s/\,//g" | awk '{nam=$2;getline;getline;ca=$2;getline;v=$2;print nam,ca,v}' > $$_rds_tls

ts_today=$(date +%s)

while read a b c
do
  notAfter=$(date -d "$c" +%s)
  days=$(( notAfter - ts_today ))
  days=$(( days / 86400 ))
  echo $a $b $c $days
done<$$_rds_tls


rm $$_rds_tls




