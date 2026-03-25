#!/bin/bash

# Path to the MySQL extra defaults file
DEFAULTS_FILE="dde-sox-new.cnf"
DB_NAME="sakila"
BACKUP_DIR="rollback_scripts"
mkdir -p "$BACKUP_DIR"

# Custom delimiter
DELIMITER="//"

# Directory containing the list of files (Git diff output)
FILES_DIR="downloaded"

# Iterate through each file in the specified directory
for FILE in "$FILES_DIR"/*; do
    # Extract the filename without the path and remove .sql extension
    FUNCTION_OR_PROCEDURE_NAME=$(basename "$FILE" .sql)

    echo "The proc/function: $FUNCTION_OR_PROCEDURE_NAME"

    # Check if it's a procedure
    IS_PROCEDURE=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE' AND ROUTINE_NAME='$FUNCTION_OR_PROCEDURE_NAME' AND ROUTINE_SCHEMA='$DB_NAME';")

    # echo "What's in the variable: $IS_PROCEDURE"

    # Check if it's a function
    IS_FUNCTION=$(mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='FUNCTION' AND ROUTINE_NAME='$FUNCTION_OR_PROCEDURE_NAME' AND ROUTINE_SCHEMA='$DB_NAME';")


    echo "DROP PROCEDURE IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" > "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"
    echo "DROP FUNCTION IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;" >> "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"

    # Generate SHOW CREATE statement based on whether it's a function or procedure
    if [[ $IS_PROCEDURE -gt 0 ]]; then
        {
#	    echo "DROP PROCEDURE IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;"

            echo "DELIMITER $DELIMITER"
            mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -e "SHOW CREATE PROCEDURE $FUNCTION_OR_PROCEDURE_NAME\G" | \
                awk '/Create Procedure:/, /^END/' | sed -e 's/Create Procedure: //' -e 's/^ *//'
            printf "$DELIMITER\n"
            echo "DELIMITER ;"
        } >> "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"
        echo "Backed up procedure: $FUNCTION_OR_PROCEDURE_NAME"
    elif [[ $IS_FUNCTION -gt 0 ]]; then
        {
#	    echo "DROP FUNCTION IF EXISTS $FUNCTION_OR_PROCEDURE_NAME;"

            echo "DELIMITER $DELIMITER"
            mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -e "SHOW CREATE FUNCTION $FUNCTION_OR_PROCEDURE_NAME\G" | \
                awk '/Create Function:/, /^END/' | sed -e 's/Create Function: //' -e 's/^ *//'
            printf "$DELIMITER\n"
            echo "DELIMITER ;"
        } >> "$BACKUP_DIR/$FUNCTION_OR_PROCEDURE_NAME.sql"
        echo "Backed up function: $FUNCTION_OR_PROCEDURE_NAME"
    else
        echo "No procedure or function found for: $FUNCTION_OR_PROCEDURE_NAME"
    fi
done

echo "Backup completed. Rollback scripts saved in $BACKUP_DIR."
