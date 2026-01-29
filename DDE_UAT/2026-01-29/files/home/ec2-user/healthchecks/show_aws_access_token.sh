#!/bin/bash

# Header for the output

# List all IAM users and their access key IDs, statuses, and ages
users=$(aws iam list-users --query 'Users[*].UserName' --output text)

for user in $users; do
	# List all access keys (active and inactive) for each user
	access_keys=$(aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[*].[AccessKeyId, Status, CreateDate]' --output text)

	if [ -z "$access_keys" ]; then
		continue  # Skip if no access keys found for the user
	else
        	# Process access keys
        	key_number=1
		echo "$access_keys" | while read -r access_key_id status create_date; do
        	# Calculate the age of the access key in days
        	create_date_seconds=$(date -d "$create_date" +%s)
       		current_time_seconds=$(date +%s)
           	age_days=$(( (current_time_seconds - create_date_seconds) / 86400 ))

            	# Print the user, access key details in CSV format
		if [[ $status == "Active" ]];then
            	  echo "$user Key_$key_number $access_key_id $status $age_days"
		fi  

		# Increment the key number for the next key
		key_number=$((key_number + 1))
	done
    fi
done
