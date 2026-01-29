#!/bin/bash
#
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log
}

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

logger "Initiate MySQL table truncate : raw_eppix_vas"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE raw_eppix_vas;" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
logger "	Successful MySQL truncate : raw_eppix_vas" 
else
logger "	Error during MySQL truncate : raw_eppix_vas" 
exit $rc
fi



logger "Initiate MySQL table insert : raw_eppix_vas"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "LOAD DATA LOCAL INFILE 'data/raw_eppix_vas_cleaned.csv' INTO TABLE raw_eppix_vas FIELDS TERMINATED BY '|' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
logger "	Successful MySQL data loaded : raw_eppix_vas" 
else
logger "	Error during MySQL data load : raw_eppix_vas"
exit $rc
fi

NUM_FILE=$(cat data/raw_eppix_vas_cleaned.csv | wc -l)
NUM_NEWSRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from raw_eppix_vas" --batch --raw --skip-column-names)

logger "Total records available in [ data/raw_eppix_vas_cleaned.csv ]: $NUM_FILE"
logger "Total records loaded to table [ raw_eppix_vas ]: $NUM_NEWSRC"

if (( $NUM_FILE == $NUM_NEWSRC ));then

logger "Data load completed without errors"
logger "======================================COMPLETED===================================================================="
else

logger "	The record counts dont match - pleasde check immediately"
exit $rc
fi




