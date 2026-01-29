#!/bin/bash

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/rotations

#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za, raeesah.khan@vcontractor.co.za, thato.mokoena1@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"
DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)

#Update the Mysql connection data (in case its changed)
~/decode-secret.sh mysql-secret default >> $$_temp

srv=$(cat $$_temp | grep host: | awk '{print $2}')
pss=$(cat $$_temp | grep password: | awk '{print "\""$2"\""}')
usr=$(cat $$_temp | grep user: | awk '{print $2}')
dbn=$(cat $$_temp | grep database: | awk '{print $2}')

echo "[client]" > dde-uat-admin.cnf
echo "user=$usr" >> dde-uat-admin.cnf
echo "password=$pss" >> dde-uat-admin.cnf
echo "host=$srv" >> dde-uat-admin.cnf
echo "database=$dbn" >> dde-uat-admin.cnf
echo "ssl-ca=/home/ec2-user/global-rds-bundle.pem" >> dde-uat-admin.cnf
echo "ssl-mode=VERIFY_CA" >> dde-uat-admin.cnf

rm $$_temp

OUT=./dde-uat-admin.cnf

#Using the Gitlab user to trigger AWS key rotations
USER_NAMES="ReadOnly admin"

for nam in $USER_NAMES
do

	AGE=$(mysql --defaults-extra-file=$OUT --raw --batch --skip-column-names -e "select timestampdiff(DAY,password_last_changed,NOW()) as password_age from mysql.user where User='$nam'")

	echo "AGE for $nam = "$AGE

	if [ $AGE -gt 83 ];then
   		./DDE-exec-password.sh $nam
		rc=$?
		if (( $rc != 0 ));then
   		   echo "There was an error trying to update the password for user $nam with age $AGE" | mutt -s "MySQL passwords change failed in the DDE UAT environment - User:$nam" $DL
		else	
          echo "The MySQL password age for user $nam was $AGE and has been changed." | mutt -s "MySQL password change executed in the DDE UAT environment - User:$nam" $DL
		fi
        else
           echo "The password age for $nam is $AGE"
	fi
done

cd ~

