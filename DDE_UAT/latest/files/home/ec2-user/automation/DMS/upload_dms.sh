#!/bin/bash


###Extrac user information from MySQL

MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin
#mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL br_sox_mysql_users" --batch --raw | sed 's/\t/,/g' > $FNAM



mysql --defaults-extra-file=/home/ec2-user/dde-sox.cnf --defaults-group-suffix=1 --batch --raw --local-infile=1 < ./dde_user_extract.sql


###Convert CSV to XLSX



###Upload XLSX file to the DMS server

#user: svc_dde
#pass: 0913Smile&@

echo "curl --cacert /home/ec2-user/automation/DMS/dms2.pem --request POST --url https://dms.vodacom.corp:8443/dms/uploadfile --header 'Content-Type: multipart/form-data' --header 'Authorization:Basic c3ZjX2RkZTowOTEzU21pbGUmQA==' --form 'file=@/home/ec2-user/automation/DMS/name.xlsx'"


