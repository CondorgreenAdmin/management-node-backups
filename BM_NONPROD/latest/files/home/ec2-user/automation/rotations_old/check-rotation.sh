#!/bin/bash

cd ~/automation/rotations

#timestamp=$(date +%Y%m%d%H%M%S)
#logfile="output_log_$timestamp"
#exec > "./logs/$logfile" 2>&1

#List of keys to be rotated
USERS=("nonprod_bm_app_user" "nonprod_bm_cli_access" "nonprod_bm_eks_control" "nonprod_bm_gitlab_ci")

for user in "${USERS[@]}"; do
	echo $user

	#Get active keys for the user
	ACTIVE_KEY=$(aws iam list-access-keys --user-name $user --query "AccessKeyMetadata[?Status=='Active'].AccessKeyId" --output text)

	echo ${ACTIVE_KEY[0]}

	if [ "${#ACTIVE_KEY[@]}" -gt 1 ]; then
		echo "More than one key active"
	fi

	CDATE=$(aws iam list-access-keys --user-name $user --query "AccessKeyMetadata[?AccessKeyId=='${ACTIVE_KEY[0]}'].{Date:CreateDate}" --output text)
	echo $CDATE
	CDATE_EPOCH=$(date -d "$CDATE" +%s)
#	CDATE_EXPIR=$((CDATE_EPOCH + 84 *24 *3600))

	TODAY_EPOCH=$(date +%s)

	KEY_AGE=$(( ($TODAY_EPOCH - $CDATE_EPOCH) / 86400 ))
	echo "Key age is $KEY_AGE"

	if [ "$KEY_AGE" -gt 84 ]; then
		echo "Key is too old. Must rotate"

		DL="michaelalex.dirks@vcontractor.co.za"
		echo "AWS key age for user $user was $KEY_AGE" | mutt -s "AWS key rotation executed for the BM NONPROD environment" -- $DL

	else
		echo "Key is younger than 84 days"
	fi
	echo


done
