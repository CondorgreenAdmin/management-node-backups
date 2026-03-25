
 DEFAULTS_FILE="dde-sox-new.cnf"
 DB_NAME="DDE-prd"


mysql --defaults-extra-file=dde-sox-new.cnf -e "select 1"


echo ""
echo ""

FUNCTION_OR_PROCEDURE_NAME=ahh_check_dealsheet_items

mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE' AND ROUTINE_NAME='$FUNCTION_OR_PROCEDURE_NAME' AND ROUTINE_SCHEMA='$DB_NAME';"



#mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -N -e \
#         "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE' AND ROUTINE_NAME='$FUNCTION_OR_PROCEDURE_NAME' AND ROUTINE_SCHEMA='$DB_NAME';"


#mysql --defaults-extra-file=dde-sox-new.cnf < $file
