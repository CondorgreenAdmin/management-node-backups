TODO=$(./create-uat-list.sh)
for nam in $TODO
do
   echo $nam
   echo '-----------------------'
   mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "SELECT ROUTINE_DEFINITION FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'DDE-prd' AND ROUTINE_NAME = '$nam'" --batch --raw --skip-column-names > uat_$nam
   echo
   echo
   echo "=============================================================================="
   echo
done
