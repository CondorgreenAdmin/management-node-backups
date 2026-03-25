#!/bin/bash
cd ~/sp_deployments

./s3_download.sh
~/release_lukhanyo/s3_download.sh

return_code=$?

if (( $return_code != 0 ));
then
	return 99
fi

command_file="commands.sql"
debug=true

master_file=sp_deployments_version_master

# Empty file
touch $command_file
rm $command_file

file_list=$(ls ./downloaded/*.sql | grep -v DropProcedures.sql)
backupnames=()
#echo $file_list
#read junk

echo "START TRANSACTION;" > $command_file
echo "" >> $command_file
echo "" >> $command_file

cat ./downloaded/DropProcedures.sql >> $command_file

for file in $file_list
do
	cat $file >> $command_file
	echo "" >> $command_file
	echo "" >> $command_file
done

echo "COMMIT;" >> $command_file

mysql --defaults-extra-file=~/sp_deployments/dde-sox-new.cnf < $command_file

error=$?

# Store version number in master file
# cat ./downloaded/package.json | grep version > $master_file


# Run sp to get latest time after our edit
version=$(cat ./downloaded/package.json | grep version | awk -F'": "' '{print $2}' | tr -d '"')

# Move file into a master file (Overwrite existing file)
humandate=$(mysql --defaults-extra-file=~/sp_deployments/dde-sox-new.cnf --defaults-group-suffix=1 -e 'CALL util_get_recent_update("DDE-prd");' --batch --raw -s)

unixtime=$(date -d "${humandate}" +%s)

#unix=$(date -d "`mysql --defaults-extra-file=~/sp_deployments/dde-sox-new.cnf --defaults-group-suffix=1 -e 'CALL util_get_recent_update("sakila");' --batch --raw -s`" +%s)
#unixtime=$(date -d "2024-10-31 17:00:00.00" +%s)

echo "$version $unixtime $humandate" >> $master_file
# echo $unixtime >> $master_file
# echo $humandate >> $master_file

# move master file
mv $master_file ..

echo "Master file completed"

if [ "$debug" == "false" ];
then
	#Cleanup s3, local
	echo "Starting to clean s3"
	aws s3 rm s3://dev-dopadde-share/sp_deployments/ --recursive
	echo "Cleaned up S3"
	echo "Starting to clean local"
	rm -r ~/sp_deployments/downloaded/
	echo "Local cleaned"
fi

if (( $error != 0 ));
then
	# Failure
	echo "500"
else
	# Success
	num=$(echo $file_list | wc -w)
	echo "Number of files updated: $num"
	echo "201"
fi


# Clean up
# error checking back to lambda to gitlab
