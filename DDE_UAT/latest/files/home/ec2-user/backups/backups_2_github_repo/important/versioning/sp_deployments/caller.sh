


#!/bin/bash

#array=("br_add_partitions_global" "fn_ms_since_then" "br_add_partitions_global" "Four" "Five" "Six")


cd /home/ec2-user/versioning/sp_deployments

./s3_download_test.sh

echo "===================="

files=($(ls downloaded/*.sql))

echo "FILES ${files[@]}"

for i in "${!files[@]}"; do
	echo "INDEX $i: ${files[$i]}"
done

#echo "Calling checkup script"
#echo "===================="

./sql_checksum.sh "${files[@]}"
