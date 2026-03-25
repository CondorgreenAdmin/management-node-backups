#!/bin/bash
#
#
logger() {

DTE=$(date +"%Y-%m-%d %H:%M:%S.%N")

echo $DTE" "$1 >> logs/status.log
}


cd ~/automation/dataloads/scripts

OUT="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"

logger "Initiate MySQL backup truncate : src_epx_packages_backup"

mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "TRUNCATE src_epx_packages_backup;" --batch --raw --local-infile=1

rc=$?
if (( $rc != 0 ));then
  logger "	Load aborted due to error during truncate"
  exit $rc
else
  logger "	Truncate succeeded"	
fi  

logger "Counting current source table records"
NUM_SRC=$(mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "select count(*) from src_epx_packages" --batch --raw --skip-column-names)
logger "	Found $NUM_SRC records"


logger "Initiate MySQL backup insert : src_epx_packages_backup"

mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "INSERT INTO src_epx_packages_backup SELECT * FROM src_epx_packages" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
   logger "	Successful MySQL backup created" 
else
   logger "	Error during MySQL backup creation" 
   exit $rc
fi


logger "Counting backup table records"

NUM_BACKUP=$(mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "select count(*) from src_epx_packages_backup" --batch --raw --skip-column-names)
logger "	Found $NUM_BACKUP records"

if (( $NUM_SRC == $NUM_BACKUP ));then

   logger "Initiate MySQL table truncate : src_epx_packages"

   mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "TRUNCATE src_epx_packages;" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL truncate : src_epx_packages" 
   else
      logger "	Error during MySQL truncate : src_epx_packages" 
      exit $rc
   fi



   logger "Initiate MySQL table insert : src_epx_packages"

   mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "LOAD DATA LOCAL INFILE 'data/cleaned_vpk_package.csv' INTO TABLE src_epx_packages FIELDS TERMINATED BY '|' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL data loaded : src_epx_packages" 
   else
      logger "	Error during MySQL data load : src_epx_packages"
      exit $rc
   fi

   NUM_FILE=$(cat data/cleaned_vpk_package.csv | wc -l)
   NUM_NEWSRC=$(mysql --defaults-extra-file=$OUT --defaults-group-suffix=1 -e "select count(*) from src_epx_packages" --batch --raw --skip-column-names)

   logger "Total records available in [ data/cleaned_vpk_package.csv ]: $NUM_FILE"
   logger "Total records loaded to table [ src_epx_packages ]: $NUM_NEWSRC"

   if (( $NUM_FILE == $NUM_NEWSRC ));then

   	logger "Data load completed without errors"
	logger "======================================COMPLETED===================================================================="
  else

	logger "	The record counts dont match - pleasde check immediately"
	exit $rc
  fi

else

  logger "	Source and Backup record counts do not match - aborting Insert"

fi

