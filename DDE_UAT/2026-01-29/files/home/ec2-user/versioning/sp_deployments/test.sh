array=()
array+="Green"
array+="Blue"
array+="Orange"

echo $array


for i in "${array[@]}"; do
	echo $i
done


array2=("apple" "bannana" "cherry")

for item in "${array2[@]}"; do
	echo "Processing: $item"
done
echo "new array ${array2[@]}"


date_time=$(date +"%Y%m%d_%H%M%S")
#mv ttt "ttt_$date_time"

log_file="sql_checksum_log_$(date +'%Y%m%d_%H%M%S')"
touch "$log_file"


#echo "HELLO WORLD" | tee "$log_file"

source ~/paths/MYSQL_PATH

cd ~/versioning/sp_deployments/
DEFAULTS_FILE="dde-sox.cnf"
DB_NAME="DDE-prd"

pwd

echo $DEFAULTS_FILE

mysql --defaults-file="$DEFAULTS_FILE" -D "$DB_NAME" -e "SELECT 1\G"
