#!/bin/bash
#
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log
}


cd ~/automation/dataloads/scripts

logger "Updating MySQL connection information"

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

logger "Initiate MySQL backup truncate : src_css_vas_qualification_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE src_css_vas_qualification_backup;" --batch --raw --local-infile=1

rc=$?
if (( $rc != 0 ));then
  logger "	Load aborted due to error during truncate"
  exit $rc
else
  logger "	Truncate succeeded"	
fi  

logger "Counting current source table records"
NUM_SRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from src_css_vas_qualification" --batch --raw --skip-column-names)
logger "	Found $NUM_SRC records"


logger "Initiate MySQL backup insert : src_css_vas_qualification_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "INSERT INTO src_css_vas_qualification_backup SELECT * FROM src_css_vas_qualification" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
   logger "	Successful MySQL backup created" 
else
   logger "	Error during MySQL backup creation" 
   exit $rc
fi


logger "Counting backup table records"

NUM_BACKUP=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from src_css_vas_qualification_backup" --batch --raw --skip-column-names)
logger "	Found $NUM_BACKUP records"

if (( $NUM_SRC == $NUM_BACKUP ));then

   logger "Initiate MySQL table insert : src_css_vas_qualification"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 < sql/load_src_css_vas_qualification.sql

   logger "Data load completed without errors"
   logger "======================================COMPLETED===================================================================="

else

  logger "	Source and Backup record counts do not match - aborting Insert"

fi

