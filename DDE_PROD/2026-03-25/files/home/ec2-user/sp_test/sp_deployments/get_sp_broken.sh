#!/bin/bash

cd ~/versioning/sp_deployments/

#Path to the MySQL extra defaults file
DEFAULTS_FILE="dde-sox-new.cnf"
DB_NAME="DDE-prd"
BACKUP_DIR="rollback_scripts"
DOWNLOAD_LOCATION="downloaded/"

mkdir -p "$BACKUP_DIR"

# Custom delimiter
DELIMITER="//"

# Directory containing the list of files (Git diff output)
#FILES_DIR="~/sp_deployments/downloaded/*.sql"
FILES_DIR=$(ls downloaded/*.sql | xargs -n 1 basename)


# Iterate through each file in the specified directory
for FILE in $(find downloaded/ -maxdepth 1 -type f -name "*.sql"); do
	echo "Working on file $FILE"
#	echo '(Processing file: $(basename "$FILE")'
    # Extract the filename without the path and remove .sql extension
    FUNCTION_OR_PROCEDURE_NAME=$(basename "$FILE" .sql)
    echo "The proc/function: $FUNCTION_OR_PROCEDURE_NAME"

    # Check if it's a procedure
    IS_PROCEDURE=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
	"SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE' AND ROUTINE_NAME='$FUNCTION_OR_PROCEDURE_NAME' AND ROUTINE_SCHEMA='$DB_NAME';")

    #echo "What's in the variable: $IS_PROCEDURE"

    # Check if it's a function
    IS_FUNCTION=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \ "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='FUNCTION' AND ROUTINE_NAME='$FUNCTION_OR_PROCEDURE_NAME' AND
        ROUTINE_SCHEMA='$DB_NAME';")
    # Check if it's a trigger
    IS_TRIGGER=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \ "SELECT COUNT(*) FROM information_schema.triggers WHERE TRIGGER_NAME='$FUNCTION_OR_PROCEDURE_NAME' AND EVENT_OBJECT_SCHEMA='$DB_NAME';")

    if [ "$IS_PROCEDURE" -eq 1 ]; then
	echo "DROP PROCEDURE IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" > "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql" 
    elif [ "$IS_FUNCTION" -eq 1 ]; then
	echo "DROP FUNCTION IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" > "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"

    elif [ "$IS_TRIGGER" -eq 1 ]; then
	echo "DROP TRIGGER IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" > "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"
    else
	echo "Object not found in DB. Checking file content for type..."
    fi

    # Check the file content for CREATE statements
#    echo "THIS IS THE FILE $FILE"
#	echo $FILE
#    echo "THIS IS THE FILE LOCATION - $FILE"
 
   if grep -iq 'CREATE PROCEDURE' "$FILE"; then
	echo "DROP PROCEDURE IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" > "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"
	echo "Identified as PROCEDURE from file."

    elif grep -iq 'CREATE FUNCTION' "$FILE"; then
	echo "DROP FUNCTION IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" > "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"
	echo "Identified as FUNCTION from file."
    elif grep -iq 'CREATE TRIGGER' "$FILE"; then
        echo "DROP TRIGGER IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" > "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"
	echo "Identified as TRIGGER from file."
    else echo "Unable to determine the type of $FUNCTION_OR_PROCEDURE_NAME. No DROP statement generated."
        continue
	fi

    # Generate SHOW CREATE statement based on whether it's a function or procedure
    if [[ $IS_PROCEDURE -gt 0 ]]; then
	{ echo "DELIMITER $DELIMITER" mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -e "SHOW CREATE PROCEDURE $FUNCTION_OR_PROCEDURE_NAME\G" | \
	sed -n '/Create Procedure:/,/character_set_client:/p' | sed -e 's/^.*Create Procedure:[[:space:]]*//' -e '/character_set_client:/d' echo "$DELIMITER" echo "DELIMITER ;"
        } >> "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"

        echo "Backed up procedure: $FUNCTION_OR_PROCEDURE_NAME"
	echo ""

    elif [[ $IS_FUNCTION -gt 0 ]]; then
	{ echo "DELIMITER $DELIMITER" mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -e "SHOW CREATE FUNCTION $FUNCTION_OR_PROCEDURE_NAME\G" | \
          sed -n '/Create Function:/,/character_set_client:/p' | sed -e 's/^.*Create Function:[[:space:]]*//' -e '/character_set_client:/d'
		echo "$DELIMITER" echo "DELIMITER ;"
	} >> "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"

        echo "Backed up function: $FUNCTION_OR_PROCEDURE_NAME"
	echo ""

    elif [[ $IS_TRIGGER -gt 0 ]]; then 
	{ echo "DELIMITER $DELIMITER" mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -e "SHOW CREATE TRIGGER $FUNCTION_OR_PROCEDURE_NAME\G" | \
        sed -n '/SQL Original Statement:/,/character_set_client:/p' | sed -e 's/^.*SQL Original Statement:[[:space:]]*//' -e '/^[[:space:]]*character_set_client:/d'
		echo "$DELIMITER" echo "DELIMITER ;"
        } >> "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"

        echo "Backed up trigger: $FUNCTION_OR_PROCEDURE_NAME"
	echo ""
	fi
done

echo "Backup completed. Rollback scripts saved in $BACKUP_DIR."
