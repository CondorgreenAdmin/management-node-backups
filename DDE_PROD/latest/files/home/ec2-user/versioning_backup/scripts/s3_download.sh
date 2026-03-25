#!/bin/bash
cd ~/versioning/scripts


# Variables
bucket_name="dev-dopadde-share"
s3_directory="sp_deployments/"
download_path="./downloaded"
crq_file="${s3_directory}crq.txt"

# Create download path if not existed
mkdir -p "${download_path}"

# Download each file to the specified local directory
aws s3 cp "s3://${bucket_name}/${crq_file}" "${download_path}/$(date +%Y%m%d).txt"

filedata=$(cat "$download_path/$(date +%Y%m%d).txt")

echo $(date +%Y-%m-%d) $filedata >> ./downloaded/CRQ.txt
