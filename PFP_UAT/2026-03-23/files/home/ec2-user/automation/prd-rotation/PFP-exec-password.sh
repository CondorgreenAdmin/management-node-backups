#!/bin/bash

OPT=$1

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/rotations

for u in $OPT
do

   DTE2=$(date +"%Y%m%d-%H%M%S")
   NEW_PASSWORD=$( { tr -dc A-Za-z < /dev/urandom | head -c1 ; tr -dc 'A-Za-z0-9_\#@%^' < /dev/urandom | head -c 19; } ) 

   echo "Date: "`date +"%Y-%m-%d %H:%M:%S"` | tee -a ~/keys/dbstatus.log
   echo "User Name: $u" | tee -a ~/keys/dbstatus.log
   echo "DB User: $OPT - new password = $NEW_PASSWORD" | tee -a ~/keys/dbstatus.log

   case $OPT in
        "prod_pfp_appuser")  

            OUT="/home/ec2-user/automation/rotations/pfp-prd-admin.cnf"
   	    ENCODED_VALUE_PASSWORD=$(echo -n "$NEW_PASSWORD" | base64)
   	    SECRET_NAME="mysql-secret"
   	    NAMESPACE="default"

	    #@update mysql	
	    mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "ALTER USER 'prod_pfp_appuser'@'%' IDENTIFIED BY '$NEW_PASSWORD';FLUSH PRIVILEGES;" --batch --raw

	    cat $OUT | grep -v "password=" > /home/ec2-user/automation/rotations/pfp-new.cnf
	    echo "password=$NEW_PASSWORD" >> /home/ec2-user/automation/rotations/pfp-new.cnf

	    mv $OUT $OUT.$DTE2
	    mv /home/ec2-user/automation/rotations/pfp-new.cnf $OUT

            # Patch the secret with the new data
            kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/password\", \"value\": \"$ENCODED_VALUE_PASSWORD\"}]" | tee -a ~/keys/dbstatus.log

            echo "$OUT updated" | tee -a ~/keys/dbstatus.log

	    #Restart 1x PODS (api
	    kubectl delete pod -l app=api | tee -a ~/keys/dbstatus.log
	    sleep 5
	    kubectl get pods | tee -a ~/keys/dbstatus.log
            echo "All PODs requiring the new password have been restarted" | tee -a ~/keys/dbstatus.log
           ;;

        "admin")  

            OUT="/home/ec2-user/automation/rotations/pfp-prd-admin.cnf"

	    #@update mysql	
	    mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "ALTER USER 'admin'@'%' IDENTIFIED BY '$NEW_PASSWORD';FLUSH PRIVILEGES;" --batch --raw | tee -a ~/keys/dbstatus.log
           ;;


        "ReadOnly") ##tested - working

            OUT="/home/ec2-user/SOX/vuma-sox.cnf"

	    #@update mysql	
	    mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "ALTER USER 'ReadOnly'@'%' IDENTIFIED BY '$NEW_PASSWORD';FLUSH PRIVILEGES;" --batch --raw | tee -a ~/keys/dbstatus.log

	    cat $OUT | grep -v "password=" > /home/ec2-user/SOX/pfp-sox_new.cnf
	    echo "password=$NEW_PASSWORD" >> /home/ec2-user/SOX/pfp-sox_new.cnf

	    mv $OUT $OUT.$DTE2
	    mv /home/ec2-user/SOX/pfp-sox_new.cnf $OUT

            echo "$OUT updated" | tee -a ~/keys/dbstatus.log
           ;;
   esac

done

echo "" | tee -a ~/keys/dbstatus.log

