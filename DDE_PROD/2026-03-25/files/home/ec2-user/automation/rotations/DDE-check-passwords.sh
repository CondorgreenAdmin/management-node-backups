#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/rotations

DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"

#Update the Mysql connection data (in case its changed)
~/decode-secret.sh mysql-secret default >> $$_temp   

srv=$(cat $$_temp | grep host: | awk '{print $2}')
pss=$(cat $$_temp | grep password: | awk '{print "\""$2"\""}')
usr=$(cat $$_temp | grep user: | awk '{print $2}')
dbn=$(cat $$_temp | grep database: | awk '{print $2}')


echo "[client]" > dde-prd-admin.cnf
echo "user=$usr" >> dde-prd-admin.cnf
echo "password=$pss" >> dde-prd-admin.cnf
echo "host=$srv" >> dde-prd-admin.cnf
echo "database=$dbn" >> dde-prd-admin.cnf
echo "ssl-ca=/home/ec2-user/global-rds-bundle.pem" >> dde-prd-admin.cnf
echo "ssl-mode=VERIFY_CA" >> dde-prd-admin.cnf

rm $$_temp

OUT=./dde-prd-admin.cnf

USER_NAMES="ReadOnly admin"

for nam in $USER_NAMES
do
	AGE=$(mysql --defaults-extra-file=$OUT --raw --batch --skip-column-names -e "select timestampdiff(DAY,password_last_changed,NOW()) as password_age from mysql.user where User='$nam'")

	if [ $AGE -gt 84 ];then
   		./DDE-exec-password.sh $nam
		rc=$?
                if (( $rc != 0 ));then
                   echo "There was an error trying to update the password for user $nam with age $AGE" | mutt -s "MySQL passwords change failed in the DDE PROD environment - User:$nam" -- $DL
                else
           	   echo "The MySQL password age for user $nam was $AGE and has been changed." | mutt -s "MySQL password change executed in the DDE PROD environment - User:$nam" -- $DL
		fi
        else
           echo "The password age for $nam is $AGE"
	fi
done

cd ~

