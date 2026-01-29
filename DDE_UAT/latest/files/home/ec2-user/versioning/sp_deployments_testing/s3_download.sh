#!/bin/bash

cd ~/versioning/sp_deployments_testing/

LOGFILE=$1
exec > >(tee -a "$LOGFILE") 2>&1

# Variables
bucket_name="dev-dopadde-share"
s3_directory="sp_deployments_test/"
download_path="./downloaded/"

# Create download path if not existed
mkdir -p "${download_path}"

# Get a list of all files in the specified S3 directory
files=$(aws s3 ls "s3://${bucket_name}/${s3_directory}" --recursive | awk '{print $4}')

if (( `echo $files | wc -w` == 0 ));
then
	echo "No files"
	exit 99
fi

# Loop through each file and download it
for file_key in $files; do

	# Download each file to the specified local directory
	aws s3 cp "s3://${bucket_name}/${file_key}" "${download_path}/$(basename ${file_key})"

	# Check if download was successful
	if [ $? -eq 0 ]; then
		echo "Downloaded: ${file_key}"
	else
		echo "Failed to download: ${file_key}"
	fi
done

echo ""
echo "Download completed"
echo "===================="
echo ""
