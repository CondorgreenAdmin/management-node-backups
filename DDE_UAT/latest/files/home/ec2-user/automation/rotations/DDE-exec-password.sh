#!/bin/bash

OPT=$1
DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za, thato.mokoena1@vcontractor.c.za, raeesah.khan@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"

export MYSQLDIR=/usr/local/mysql-8.0.40-linux-glibc2.17-x86_64-minimal/bin

export PATH=$MYSQLDIR:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

export SHELL=/bin/bash

cd ~/automation/rotations


#create new passwords	

CNF="/home/ec2-user/automation/rotations/dde-uat-admin.cnf"
DTE2=$(date +"%Y%m%d-%H%M%S")
NEW_PASSWORD=$(tr -dc A-Za-z0-9_\#@%^=?+ < /dev/urandom | head -c 20) 

echo "Date: "`date +"%Y-%m-%d %H:%M:%S"` | tee -a ~/keys/dbstatus.log
echo "==============================================================" | tee -a ~/keys/dbstatus.log
echo "DB User: $OPT - new password = $NEW_PASSWORD" | tee -a ~/keys/dbstatus.log

case $OPT in
        "admin")  

            OUT="/home/ec2-user/automation/rotations/dde-uat-admin.cnf"
   	    ENCODED_VALUE_PASSWORD=$(echo -n "$NEW_PASSWORD" | base64)
   	    SECRET_NAME="mysql-secret"
   	    NAMESPACE="default"

	    #@update mysql	
	    mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 -e "ALTER USER 'admin'@'%' IDENTIFIED BY '$NEW_PASSWORD';FLUSH PRIVILEGES;" --batch --raw

	    rc=$?
	    if (( $rc != 0 ));then
               echo "ERROR trying to set the new password. Aborted update" | tee -a ~/keys/dbstatus.log
               return $rc
            else
	       cat $OUT | grep -v "password=" > dde-new.cnf
	       echo "password=\"$NEW_PASSWORD\"" >> dde-new.cnf

	       mv $OUT $OUT.$DTE2
	       mv dde-new.cnf $OUT

               # Patch the secret with the new data
               kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/password\", \"value\": \"$ENCODED_VALUE_PASSWORD\"}]" | tee -a ~/keys/dbstatus.log
	       err1=$?

               if (( $err1 != 0 ));then
                  hostname=`hostname`
                  echo -e "kubectl patch secret: $SECRET_NAME\n\nerr1=$err1" | mutt -s "ERROR: $hostname kubectl secret updates failed: Please investigate" -- $DL
		  return $err1
               else
                  echo "dde-uat-admin.cnf updated" | tee -a ~/keys/dbstatus.log
	          #Restart 3x PODS (dde, loader, worker
	          kubectl delete pod -l app=dde | tee -a ~/keys/dbstatus.log
	          sleep 5
	          kubectl delete pod -l app=worker | tee -a ~/keys/dbstatus.log
	          sleep 5
	          kubectl delete pod -l app=loader | tee -a ~/keys/dbstatus.log
	          sleep 5
	          echo "PODs (dde, worker and loader) have been restarted" | tee -a ~/keys/dbstatus.log
	       fi	  
	       kubectl get pods | tee -a ~/keys/dbstatus.log
	    fi   
           ;;

        "ReadOnly") ##tested - working

            OUT="/home/ec2-user/dde-sox.cnf"

	    #@update mysql	
	    mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 -e "ALTER USER 'ReadOnly'@'%' IDENTIFIED BY '$NEW_PASSWORD';FLUSH PRIVILEGES;" --batch --raw

	    rc=$?
	    if (( $rc != 0 ));then
               echo "ERROR trying to set the new password. Aborted update" | tee -a ~/keys/dbstatus.log
	       return $rc
	    else	    
	       cat $OUT | grep -v "password=" > /home/ec2-user/dde-sox_new.cnf
	       echo "password=\"$NEW_PASSWORD\"" >> /home/ec2-user/dde-sox_new.cnf

	       mv $OUT $OUT.$DTE2
	       mv /home/ec2-user/dde-sox_new.cnf $OUT

               echo "dde-sox.cnf updated" | tee -a ~/keys/dbstatus.log
	    fi
           ;;
esac


echo "" | tee -a ~/keys/dbstatus.log
sync
echo "Password changes complete. Please update your credentials with the new password."
