#!/bin/bash
# Checksum script.
# Script is to get what was deployed and compare what is in the database(has been dployed) to what we wanted to deploy (S3)

cd ~/versioning/sp_deployments_testing/
source ~/paths/MYSQL_PATH

DEFAULTS_FILE="dde-sox-new.cnf"
DB_NAME="sakila"
#array=("$@")

# Create local log file
log_file="./logs/sql_checksum/sql_checksum_log_$(date +'%Y%m%d_%H%M%S')"
touch "$log_file"

mkdir -p checksum_scripts

# Cleanup and maintenance
# date_time=$(date +"%Y%m%d_%H%M%S")
# mv checksum_scripts "checksumscripts_$date_time"

echo "=========CHECKSUM==========="

array=($(ls downloaded/*.sql))

echo "FILES ${array[@]}"

for i in "${!array[@]}"; do
        echo "INDEX $i: ${array[$i]}"
done


strip_mysql(){
        STRIPPED_COMMAND="$1"
        # Removing the definer
        STRIPPED_COMMAND=$(echo "$STRIPPED_COMMAND" | sed 's/DEFINER=[^ ]* //g')
#	echo "${STRIPPED_COMMAND}"
#	exit
        STRIPPED_COMMAND=$(echo "$STRIPPED_COMMAND" | sed -n '/CREATE /,$p')
	STRIPPED_COMMAND=$(echo "${STRIPPED_COMMAND}" | sed 's/^[^:]*: //')
	STRIPPED_COMMAND=$(echo "${STRIPPED_COMMAND}" | sed '/utf8mb4/d')
	echo "${STRIPPED_COMMAND}"
 }

checksum(){
	input="$1"
	status="$2"
	item="$3"

	echo "Stripping what was received from the database"
        output=$(strip_mysql "${status}")
        echo $output > checksum_scripts/${item}
        echo "Saved stripped file as checksum_scripts/${item}"
        #echo "Output above"
#       echo "===================="
        #echo "This is the output from S3"

        # Remove all white space so the existing and change are the same format
        change=$(cat downloaded/${item}.sql | sed ':a;N;$!ba;s/\s\+/ /g' | sed 's/^\s*//;s/\s*$//')
        echo $change > s3_temp_compare
#	echo $change > bbb

	if  [[ "$input" == "PROC" ]]; then
        	echo -n "DROP PROCEDURE IF EXISTS \`${item}\`; DELIMITER // " > db_temp_compare
	elif [[ "$input" == "FUNC" ]]; then
		echo -n "DROP FUNCTION IF EXISTS \`${item}\`; DELIMITER // " > db_temp_compare
	elif [[ "$input" == "TRIG" ]]; then
		echo -n "DROP TRIGGER IF EXISTS \`${item}\`; DELIMITER // " > db_temp_compare
	elif [[ "$input" == "VIEW" ]]; then
		echo -n "DROP VIEW IF EXISTS \`${item}\`; " > db_temp_compare
	fi

	echo -n $output >> db_temp_compare
        echo "// DELIMITER ;" >> db_temp_compare
	#echo ";" >> db_temp_compare
        sed -i 's/\\\\/\\/g' db_temp_compare

	if [ "$(md5sum db_temp_compare | cut -d ' ' -f1)" = "$(md5sum s3_temp_compare | cut -d ' ' -f1)" ]; then
		echo "${item} - diff check passed"
		((diff_pass_count++))
		diff_pass_list+=("$item")
	else
		echo "Diff check FAILED with the below error"
		((diff_fail_count++))
                diff_fail_list+=("$item")
	fi
 }



echo "This is what was received from S3"
for item in "${array[@]}"; do
	echo "${item}"
done

echo "==================="

dbname=()
# Removing the .sql extensions
for f in "${array[@]}"; do
	basename=$(basename "$f")
#	echo "This is the basename - ${basename}"
        dbname+=("${basename%.*}")
#	echo "Adding item to new array: ${f%.*}"
done

#echo "New array ${dbname[@]}"

echo "New array indices:"
for i in "${!dbname[@]}"; do
        echo "Index $i: ${dbname[$i]}"
done

#declare -p dbname

echo ""
#echo "======================================"
 #echo ""


# Loop through each change and compare it to what was implemented
echo "Checksum is starting"

diff_fail_count=0
diff_pass_count=0
diff_fail_list=()
diff_pass_list=()

for item in "${dbname[@]}"; do
	echo "Getting ${item} from the database"


	# Check if it's a procedure
	IS_PROCEDURE=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
		"SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE' AND ROUTINE_NAME='$item' AND ROUTINE_SCHEMA='$DB_NAME';")
#	echo "What's in the variable PROC: $IS_PROCEDURE"

	# Check if it's a function
	IS_FUNCTION=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
		"SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='FUNCTION' AND ROUTINE_NAME='$item' AND ROUTINE_SCHEMA='$DB_NAME';")
#	echo "What's in the variable FUNC: $IS_FUNCTION"

	# Check if it's a trigger
	IS_TRIGGER=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
		"SELECT COUNT(*) FROM information_schema.triggers WHERE TRIGGER_NAME='$item' AND EVENT_OBJECT_SCHEMA='$DB_NAME';")
#	echo "What's in the variable TRIG: $IS_TRIGGER"

	# Check if it's a view
	IS_VIEW=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
		"SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME='$item' AND TABLE_SCHEMA='$DB_NAME';")
#	echo "What's in the variable VIEW: $IS_VIEW"

	if [[ $IS_PROCEDURE -gt 0 ]]; then
		PROC_STATUS=$(mysql --defaults-file="$DEFAULTS_FILE" -e "SHOW CREATE PROCEDURE ${item}\G")
		checksum "PROC" "${PROC_STATUS}" "${item}"

	elif [[ $IS_FUNCTION -gt 0 ]]; then
		FUNC_STATUS=$(mysql --defaults-file="$DEFAULTS_FILE" -e "SHOW CREATE FUNCTION ${item}\G")
                checksum "FUNC" "${FUNC_STATUS}" "${item}"

        elif [[ $IS_TRIGGER -gt 0 ]]; then
                TRIG_STATUS=$(mysql --defaults-file="$DEFAULTS_FILE" -e "SHOW CREATE TRIGGER ${item}\G")
		checksum "TRIG" "${TRIG_STATUS}" "${item}"

	elif [[ $IS_VIEW -gt 0 ]]; then
		VIEW_STATUS=$(mysql --defaults-file="$DEFAULTS_FILE" -e "SHOW CREATE VIEW ${item}\G")
		checksum "VIEW" "${VIEW_STATUS}" "${item}"
	else
		echo "*****************************"
		echo "ERROR - Your change is not a stored proc, func, trig or view"
		echo "See below return from MYSQL"
                echo "*****************************"
	fi
	echo "=========================="

done

echo ""

echo "List of diff checks that failed"
for item in "${diff_fail_list[@]}"; do
	echo "$item"
done

echo ""
echo "List of diff checks that passed"
for item in "${diff_pass_list[@]}"; do
	echo "$item"
done

echo ""
echo "Total diff checks that failed ${diff_fail_count}"
echo "Total diff checks that passed ${diff_pass_count}"

# Cleanup and maintenance
date_time=$(date +"%Y%m%d_%H%M%S")
#mv checksum_scripts "archive_checksum/checksum_scripts_$date_time"

