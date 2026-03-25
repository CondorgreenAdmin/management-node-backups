#!/bin/bash
# Checksum script.
# Script is to get what was deployed and compare what is in the database(has been dployed) to what we wanted to deploy (S3)

cd ~/versioning/sp_deployments/

DEFAULTS_FILE="dde-sox-new.cnf"
DB_NAME="DDE-prd"
#array=("$@")

# Create local log file
log_file="logs/sql_checksum_log_$(date +'%Y%m%d_%H%M%S')"
touch "$log_file"

mkdir -p checksum_scripts

# Cleanup and maintenance
# date_time=$(date +"%Y%m%d_%H%M%S")
# mv checksum_scripts "checksumscripts_$date_time"

echo "===================="

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

	echo "This is a - ${input}" | tee "$log_file"

        echo "Stripping what was received from the database" | tee "$log_file"
        output=$(strip_mysql "${status}")
        echo $output > checksum_scripts/${item}
        echo "Saved stripped file as checksum_scripts/${item}" | tee "$log_file"
        #echo "Output above"
#       echo "===================="
        #echo "This is the output from S3"

        # Remove all white space so the existing and change are the same format
        change=$(cat downloaded/${item}.sql | sed ':a;N;$!ba;s/\s\+/ /g' | sed 's/^\s*//;s/\s*$//')
        echo $change > s3_temp_compare

	if  [[ "$input" == "PROC" ]]; then
        	echo -n "DROP PROCEDURE IF EXISTS \`${item}\`; DELIMITER // " > db_temp_compare
	elif [[ "$input" == "FUNC" ]]; then
		echo -n "DROP FUNCTION IF EXISTS \`${item}\`; DELIMITER // " > db_temp_compare
	elif [[ "$input" == "TRIG" ]]; then
		echo -n "DROP TRIGGER IF EXISTS \`${item}\`; DELIMITER // " > db_temp_compare
	fi

	echo -n $output >> db_temp_compare
        echo "// DELIMITER ;" >> db_temp_compare
        sed -i 's/\\\\/\\/g' db_temp_compare
        compare=$(diff s3_temp_compare db_temp_compare)
        if $compare; then
		echo "${item} - diff check passed" | tee "$log_file"
                ((diff_pass_count++))
                diff_pass_list+=("$item")
	else
		echo "Diff check FAILED with the below error" | tee "$log_file"
                ((diff_fail_count++))
                diff_fail_list+=("$item")
                #echo "This is the diff (${compare})"
        fi
      	echo "This is the diff output - (${compare})" | tee "$log_file"
 }



echo "This is what was received from S3" | tee "$log_file"
for item in "${array[@]}"; do
	echo "${item}" | tee "$log_file"
done

echo "====================" | tee "$log_file"

dbname=()
# Removing the .sql extensions
for f in "${array[@]}"; do
	basename=$(basename "$f")
#	echo "This is the basename - ${basename}"
        dbname+=("${basename%.*}")
#	echo "Adding item to new array: ${f%.*}"
done

#echo "New array ${dbname[@]}"

echo "New array indices:" | tee "$log_file"
for i in "${!dbname[@]}"; do
        echo "Index $i: ${dbname[$i]}" | tee "$log_file"
done

#declare -p dbname

echo "" | tee "$log_file"
#echo "======================================"
 #echo ""


# Loop through each change and compare it to what was implemented
echo "Checksum is starting" | tee "$log_file"

diff_fail_count=0
diff_pass_count=0
diff_fail_list=()
diff_pass_list=()

for item in "${dbname[@]}"; do
        echo "Checking ${item}" | tee "$log_file"
	echo "Getting ${item} from the database" | tee "$log_file"




	# Check if it's a procedure
	IS_PROCEDURE=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
		"SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE' AND ROUTINE_NAME='$item' AND ROUTINE_SCHEMA='$DB_NAME';")
	#echo "What's in the variable: $IS_PROCEDURE"

	# Check if it's a function
	IS_FUNCTION=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
		"SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='FUNCTION' AND ROUTINE_NAME='$item' AND ROUTINE_SCHEMA='$DB_NAME';")
	#echo "What's in the variable: $IS_FUNCTION"

	# Check if it's a trigger
	IS_TRIGGER=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
		"SELECT COUNT(*) FROM information_schema.triggers WHERE TRIGGER_NAME='$item' AND EVENT_OBJECT_SCHEMA='$DB_NAME';")

	if [[ $IS_PROCEDURE -gt 0 ]]; then
		echo "Your change is a PROCEDURE" | tee "$log_file"
		PROC_STATUS=$(mysql --defaults-file="$DEFAULTS_FILE" -e "SHOW CREATE PROCEDURE ${item}\G")
		checksum "PROC" "${PROC_STATUS}" "${item}"

	elif [[ $IS_FUNCTION -gt 0 ]]; then
		echo "Your change is a FUNCTION" | tee "$log_file"
		FUNC_STATUS=$(mysql --defaults-file="$DEFAULTS_FILE" -e "SHOW CREATE FUNCTION ${item}\G")
                checksum "FUNC" "${FUNC_STATUS}" "${item}"

        elif [[ $IS_TRIGGER -gt 0 ]]; then
                echo "Your change is a TRIGGER" | tee "$log_file"
                TRIG_STATUS=$(mysql --defaults-file="$DEFAULTS_FILE" -e "SHOW CREATE TRIGGER ${item}\G")
		checksum "TRIG" "${TRIG_STATUS}" "${item}"

	else
		echo "*****************************" | tee "$log_file"
		echo "ERROR - Your change is not a stored proc" | tee "$log_file"
                echo "*****************************" | tee "$log_file"
	fi
	echo "==========================" | tee "$log_file"
	echo "Moving onto the next" | tee "$log_file"

done

echo "" | tee "$log_file"

echo "List of diff checks that failed" | tee "$log_file"
for item in "${diff_fail_list[@]}"; do
	echo "$item" | tee "$log_file"
done

echo "" | tee "$log_file"
echo "List of diff checks that passed" | tee "$log_file"
for item in "${diff_pass_list[@]}"; do
	echo "$item" | tee "$log_file"
done

echo "" | tee "$log_file"
echo "Total diff checks that failed ${diff_fail_count}" | tee "$log_file"
echo "Total diff checks that passed ${diff_pass_count}" | tee "$log_file"

# Cleanup and maintenance
date_time=$(date +"%Y%m%d_%H%M%S")
mv checksum_scripts "checksum_scripts_$date_time"

