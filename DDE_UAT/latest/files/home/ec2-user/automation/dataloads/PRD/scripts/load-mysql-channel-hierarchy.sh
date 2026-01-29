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

logger "Initiate MySQL backup truncate : dealer_channel"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_channel_backup;" --batch --raw --local-infile=1

rc=$?
if (( $rc != 0 ));then
  logger "	Load aborted due to error during truncate"
  exit $rc
else
  logger "	Truncate succeeded"	
fi  

logger "Counting current source table records"
NUM_SRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_channel" --batch --raw --skip-column-names)
logger "	Found $NUM_SRC records"


logger "Initiate MySQL backup insert : dealer_channel_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "INSERT INTO dealer_channel_backup SELECT * FROM dealer_channel" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
   logger "	Successful MySQL backup created" 
else
   logger "	Error during MySQL backup creation" 
   exit $rc
fi


logger "Counting backup table records"

NUM_BACKUP=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_channel_backup" --batch --raw --skip-column-names)
logger "	Found $NUM_BACKUP records"

if (( $NUM_SRC == $NUM_BACKUP ));then

   logger "Initiate MySQL table truncate : dealer_channel"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_channel;" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL truncate : dealer_channel" 
   else
      logger "	Error during MySQL truncate : dealer_channel" 
      exit $rc
   fi



   logger "Initiate MySQL table insert : dealer_channel"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "LOAD DATA LOCAL INFILE 'data/cleaned_dealer_channel.csv' INTO TABLE dealer_channel FIELDS TERMINATED BY '|' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL data loaded : dealer_channel" 
   else
      logger "	Error during MySQL data load : dealer_channel"
      exit $rc
   fi

   NUM_FILE=$(cat data/cleaned_dealer_channel.csv | wc -l)
   NUM_NEWSRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_channel" --batch --raw --skip-column-names)

   logger "Total records available in [ data/cleaned_dealer_channel.csv ]: $NUM_FILE"
   logger "Total records loaded to table [ dealer_channel ]: $NUM_NEWSRC"

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

#-------------------------------------------------------------------------------------------------------------------------------



logger "Initiate MySQL backup truncate : dealer_sub_channel_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_sub_channel_backup;" --batch --raw --local-infile=1

rc=$?
if (( $rc != 0 ));then
  logger "	Load aborted due to error during truncate"
  exit $rc
else
  logger "	Truncate succeeded"	
fi  

logger "Counting current source table records"
NUM_SRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_sub_channel" --batch --raw --skip-column-names)
logger "	Found $NUM_SRC records"


logger "Initiate MySQL backup insert : dealer_sub_channel_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "INSERT INTO dealer_sub_channel_backup SELECT * FROM dealer_sub_channel" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
   logger "	Successful MySQL backup created" 
else
   logger "	Error during MySQL backup creation" 
   exit $rc
fi


logger "Counting backup table records"

NUM_BACKUP=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_sub_channel_backup" --batch --raw --skip-column-names)
logger "	Found $NUM_BACKUP records"

if (( $NUM_SRC == $NUM_BACKUP ));then

   logger "Initiate MySQL table truncate : dealer_sub_channel"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_sub_channel;" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL truncate : dealer_sub_channel" 
   else
      logger "	Error during MySQL truncate : dealer_sub_channel" 
      exit $rc
   fi



   logger "Initiate MySQL table insert : dealer_sub_channel"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "LOAD DATA LOCAL INFILE 'data/cleaned_dealer_sub_channel.csv' INTO TABLE dealer_sub_channel FIELDS TERMINATED BY '|' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL data loaded : dealer_sub_channel" 
   else
      logger "	Error during MySQL data load : dealer_sub_channel"
      exit $rc
   fi

   NUM_FILE=$(cat data/cleaned_dealer_sub_channel.csv | wc -l)
   NUM_NEWSRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_sub_channel" --batch --raw --skip-column-names)

   logger "Total records available in [ data/cleaned_dealer_sub_channel.csv ]: $NUM_FILE"
   logger "Total records loaded to table [ dealer_sub_channel ]: $NUM_NEWSRC"

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

#-------------------------------------------------------------------------------------------------------------------------------



logger "Initiate MySQL backup truncate : dealer_group_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_group_backup;" --batch --raw --local-infile=1

rc=$?
if (( $rc != 0 ));then
  logger "	Load aborted due to error during truncate"
  exit $rc
else
  logger "	Truncate succeeded"	
fi  

logger "Counting current source table records"
NUM_SRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_group" --batch --raw --skip-column-names)
logger "	Found $NUM_SRC records"


logger "Initiate MySQL backup insert : dealer_group_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "INSERT INTO dealer_group_backup SELECT * FROM dealer_group" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
   logger "	Successful MySQL backup created" 
else
   logger "	Error during MySQL backup creation" 
   exit $rc
fi


logger "Counting backup table records"

NUM_BACKUP=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_group_backup" --batch --raw --skip-column-names)
logger "	Found $NUM_BACKUP records"

if (( $NUM_SRC == $NUM_BACKUP ));then

   logger "Initiate MySQL table truncate : dealer_group"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_group;" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL truncate : dealer_group" 
   else
      logger "	Error during MySQL truncate : dealer_group" 
      exit $rc
   fi



   logger "Initiate MySQL table insert : dealer_group"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "LOAD DATA LOCAL INFILE 'data/cleaned_dealer_group.csv' INTO TABLE dealer_group FIELDS TERMINATED BY '|' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL data loaded : dealer_group" 
   else
      logger "	Error during MySQL data load : dealer_group"
      exit $rc
   fi

   NUM_FILE=$(cat data/cleaned_dealer_group.csv | wc -l)
   NUM_NEWSRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_group" --batch --raw --skip-column-names)

   logger "Total records available in [ data/cleaned_dealer_group.csv ]: $NUM_FILE"
   logger "Total records loaded to table [ dealer_group ]: $NUM_NEWSRC"

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

#-------------------------------------------------------------------------------------------------------------------------------



logger "Initiate MySQL backup truncate : dealer_master_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_master_backup;" --batch --raw --local-infile=1

rc=$?
if (( $rc != 0 ));then
  logger "	Load aborted due to error during truncate"
  exit $rc
else
  logger "	Truncate succeeded"	
fi  

logger "Counting current source table records"
NUM_SRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_master" --batch --raw --skip-column-names)
logger "	Found $NUM_SRC records"


logger "Initiate MySQL backup insert : dealer_master_backup"

mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "INSERT INTO dealer_master_backup SELECT * FROM dealer_master" --batch --raw --local-infile=1

rc=$?
if (( $rc == 0 ));then
   logger "	Successful MySQL backup created" 
else
   logger "	Error during MySQL backup creation" 
   exit $rc
fi


logger "Counting backup table records"

NUM_BACKUP=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_master_backup" --batch --raw --skip-column-names)
logger "	Found $NUM_BACKUP records"

if (( $NUM_SRC == $NUM_BACKUP ));then

   logger "Initiate MySQL table truncate : dealer_master"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "TRUNCATE dealer_master;" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL truncate : dealer_master" 
   else
      logger "	Error during MySQL truncate : dealer_master" 
      exit $rc
   fi



   logger "Initiate MySQL table insert : dealer_master"

   mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "LOAD DATA LOCAL INFILE 'data/cleaned_dealer_master.csv' INTO TABLE dealer_master FIELDS TERMINATED BY '|' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" --batch --raw --local-infile=1

   rc=$?
   if (( $rc == 0 ));then
      logger "	Successful MySQL data loaded : dealer_master" 
   else
      logger "	Error during MySQL data load : dealer_master"
      exit $rc
   fi

   NUM_FILE=$(cat data/cleaned_dealer_master.csv | wc -l)
   NUM_NEWSRC=$(mysql --defaults-extra-file=./dde-uat-admin.cnf --defaults-group-suffix=1 -e "select count(*) from dealer_master" --batch --raw --skip-column-names)

   logger "Total records available in [ data/cleaned_dealer_master.csv ]: $NUM_FILE"
   logger "Total records loaded to table [ dealer_master ]: $NUM_NEWSRC"

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

#-------------------------------------------------------------------------------------------------------------------------------



