#!/bin/bash
cd ~/versioning/sp_deployments/
source ~/paths/MYSQL_PATH

LOGFILE="./logs/output_logs/output_logs_$(date +%Y%m%d_%H%M).log"

#if [[ ! -f "$LOGFILE" ]]; then
#	touch "$LOGFILE"
> $LOGFILE
exec > >(tee -a "$LOGFILE") 2>&1

./s3_download.sh "$LOGFILE"

return_code=$?

if (( $return_code != 0 ));
then
	return 99
fi

command_file="commands.sql"

debug=false

master_file=sp_deployments_version_master

# Empty file
touch $command_file
rm $command_file

file_list=$(ls ./downloaded/*.sql)
backupnames=()
mysqlfailed=false
changed_array=()

#echo $file_list
#read junk

# Backups ( Restore point)
./get_sp.sh "$LOGFILE"

backuplist=$(ls ./rollback_scripts/*.sql)

for file in $file_list
do
	#cat $file >> $command_file
#	echo ""
#	echo "Working on ${file}"
	name=$(basename "$file")
	changed_array+=("${name}")
#	echo "Adding ${name} to the changed_array - Applying to the databse"

	mysql --defaults-extra-file=dde-sp-depl-admin.cnf --comments < $file
	error=$?
#	echo "Return from mysql client command ${error}"
	if (( $error != 0 ));
	then
		mysqlfailed=true
		echo "An error occured with MySQL command"
		echo "ERROR: ${name} failed to execute with error: ${error}" >&2
		break
	fi

done

if [ "$mysqlfailed" = true ];
then
#	echo "" > rollback.sql
#	echo "___________________________"
#	echo "Procs and Funcs to rollback"
#	echo "${changed_array[@]}"
#	echo "___________________________"

	#RUN BACKUP SCRIPTS
#	echo ""
#	echo "Begining Rollback process. Creating rollback file"
	for file in "${changed_array[@]}";
	do
		proc_name="${file%.*}"
#		echo "Adding ${proc_name} to rollback file"

		#  adding proc file to rollback file
		cat rollback_scripts/${file} >> rollback.sql
#		echo "" >> rollback.sql
#		echo "" >> rollback.sql

		#echo "Successfully rolledback ${proc_name}"
		#echo ""
	done
#	echo "Beginning execution of rollback file"
	mysql --defaults-extra-file=dde-sp-depl-admin.cnf --comments < rollback.sql
#	echo "Output of rollback mysql execution ${?}"

	if [ "${?}" -ne "0" ];
	then
#		echo "----------------------------------"
#		echo "ROLLBACK FAILED!"
#		echo "----------------------------------"
		debug=true
	fi
fi

# Store version number in master file
# cat ./downloaded/package.json | grep version > master_file


# Run sp to get latest time after our edit
version=$(cat ./downloaded/package.json | grep version | awk -F'": "' '{print $2}' | tr -d '"')

# Move file into a master file (Overwrite existing file)
humandate=$(mysql --defaults-extra-file=dde-sp-depl-admin.cnf --defaults-group-suffix=1 -e 'CALL util_get_recent_update("DDE-prd");' --batch --raw -s)

unixtime=$(date -d "${humandate}" +%s)

#echo ""

echo "$version $unixtime $humandate" >> $master_file
# echo $unixtime >> master_file
# echo $humandate >> master_file

# move master_file
mv $master_file ..

#echo "Master file completed"

date_time=$(date +"%Y%m%d_%H%M%S")

# Checksum
#./sql_checksum.sh

if [ "$debug" == "false" ];
then
	#Cleanup s3, local
#	echo "Starting to clean s3"
	aws s3 mv s3://dev-dopadde-share/sp_deployments/ s3://dev-dopadde-share/sp_deployments_archive/$version/ --recursive >> /dev/null
#	echo "Cleaned up S3"
#	echo "Starting to clean local"
	mv downloaded "./archive_downloaded/downloaded_${date_time}"
	mv rollback_scripts "./archive_rollback/rollback_scripts_${date_time}"
#	echo "Local cleaned"
fi

if (( $error != 0 ));
then
	# Failure
	echo "There was an error - 500"
else
	# Success
	num=$(echo $file_list | wc -w)
	echo "Number of files updated: $num"
	echo "201"
fi

# Clean up
# error checking back to lambda to gitlab


#Email log file to developers
DL="michaelalex.dirks@vcontractor.co.za, sivuyile.sifuba@vcontractor.co.za, thato.mokoena1@vcontractor.co.za, yusuf.pinn@vcontractor.co.za"
#DL="michaelalex.dirks@vcontractor.co.za"
#echo "Please find logs attached for the SP deployments :-)" | mutt -s "DDE UAT SP_Deployment log file - $(date +%Y%m%d_%H%M)" -a "$LOGFILE" -- "$DL"
