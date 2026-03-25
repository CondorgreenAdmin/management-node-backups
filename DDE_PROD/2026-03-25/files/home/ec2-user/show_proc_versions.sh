#!/bin/bash

#kubectl get pods > $$kubedata

#llist="client-depl dde-depl loader-depl worker-depl"

touch $$temp
rm $$temp

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin
export PATH=$MYSQLDIR:$PATH

#echo "Object Release Published_timestamp Version Running_timestamp Version" >> $$tem
#echo "Stored#Procedures 1.1.123 2121321321 29#Oct#2024 "  >> $$temp

#which mysql

updatedDate=$(mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL util_get_recent_update('DDE-prd')" --batch --raw -s)
unixDate=$(date -d "$updatedDate" +%s)
updateDateString=$(echo $updatedDate | sed "s/ /#/g")

releaseInfo=$(cat master_file | awk '{print $1,$3"#"$4,$2}')

echo -n "Stored#Procedures#&#Functions $releaseInfo $updateDateString $unixDate" > $$temp

cat $$temp
echo

rm $$temp

