#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/rotations

DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za"
DL="arnulf.hanauer@vcontractor.co.za"

USER_NAMES="ReadOnly admin prod_pfp_appuser"
#USER_NAMES="ReadOnly"

~/decode-secret.sh mysql-secret default >> $$_temp   ###The app user has full admin priviledge

srv=$(cat $$_temp | grep host: | awk '{print $2}')
pss=$(cat $$_temp | grep password: | awk '{print "\""$2"\""}')
usr=$(cat $$_temp | grep user: | awk '{print $2}')
dbn=$(cat $$_temp | grep database: | awk '{print $2}')


echo "[client]" > pfp-prd-admin.cnf
echo "user=$usr" >> pfp-prd-admin.cnf
echo "password=$pss" >> pfp-prd-admin.cnf
echo "host=$srv" >> pfp-prd-admin.cnf
echo "database=$dbn" >> pfp-prd-admin.cnf
echo "ssl-ca=/home/ec2-user/af-south-1-bundle-rds-bundle.pem" >> pfp-prd-admin.cnf
echo "ssl-mode=VERIFY_CA" >> pfp-prd-admin.cnf

rm $$_temp

OUT=./pfp-prd-admin.cnf


for nam in $USER_NAMES
do

	AGE=$(mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 --batch --raw --skip-column-names -e "select timestampdiff(DAY,password_last_changed,NOW()) as password_age from mysql.user where User='$nam'")

	#echo "AGE for $nam = "$AGE

	if [ $AGE -gt 83 ];then
   	   ./PFP-exec-password.sh $nam
   	   echo "MySQL password age for user $nam was $AGE" | mutt -s "MySQL passwords change executed in the PFP PROD environment - User:$nam" $DL
	else
	   echo "The password age for $nam is $AGE"	
	fi
done

cat $OUT

cd ~

