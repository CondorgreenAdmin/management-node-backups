#!/bin/bash

#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za, raeesah.khan@vcontractor.co.za, thato.mokoena1@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"

#DL="michaelalex.dirks@vcontractor.co.za"

DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)

cd ~/automation/rotations

for user in rpa sfg github-ci dev-dde-eksctl dopadde-programmtic-access
do
   USER_NAME=$user
   echo "Checking keys for user: $USER_NAME"

   # Get key information from AWS
   KEY_INFO=$(aws iam list-access-keys --user-name "$USER_NAME")

   # Get all key details with IDs, status and creation dates
   KEY_DETAILS=$(echo "$KEY_INFO" | jq -r '.AccessKeyMetadata[] | "\(.AccessKeyId)|\(.Status)|\(.CreateDate)"')

   # Initialize variable to track the newest key for rotation logic
   NEWEST_KEY_DTE=0
   NEWEST_KEY_ID=""

   # Check if we found any keys
   if [ -z "$KEY_DETAILS" ]; then
      echo "No keys found for user $USER_NAME"
      echo
      continue
   fi

   echo "Individual key details:"
   # Process each key
   while IFS="|" read -r KEY_ID KEY_STATUS KEY_DATE; do
      # Calculate key age
      KEY_DTE=$(date -d "$KEY_DATE" +"%s")
      NOW_DTE=$(date +"%s")
      KEY_AGE_DAYS=$(( ( NOW_DTE - KEY_DTE ) / 86400 ))

      # Display information for this key
      echo "  Key ID: $KEY_ID"
      echo "  Status: $KEY_STATUS"
      echo "  Created: $KEY_DATE"
      echo "  Age: $KEY_AGE_DAYS days"
      echo

      # Keep track of the newest key for rotation logic
      if [ "$KEY_DTE" -gt "$NEWEST_KEY_DTE" ]; then
         NEWEST_KEY_DTE=$KEY_DTE
         NEWEST_KEY_ID=$KEY_ID
      fi
   done <<< "$KEY_DETAILS"

   # Calculate days since newest key creation for rotation logic
   NOW_DTE=$(date +"%s")
   ddiff=$(( ( NOW_DTE - NEWEST_KEY_DTE ) / 86400 ))

   echo "Most recent key is: $NEWEST_KEY_ID (age: $ddiff days)"

   # Check if rotation is needed based on newest key age
   if [ $ddiff -gt 84 ]; then
      echo "Key rotation needed for $USER_NAME (newest key age: $ddiff days)"
      ./DDE-exec-rotation.sh $user
      rc=$?
      if (( $rc != 0 )); then
         #echo "AWS key rotation has failed for user $USER_NAME" | mutt -s "ERROR: AWS keys rotation failed in the PFP PROD environment" -- $DL
         echo "AWS key rotation has failed for user $USER_NAME"
      else
         #echo "AWS key age for user $USER_NAME was $ddiff" | mutt -s "AWS keys rotation executed for the PFP PROD environment" -- $DL
         echo "AWS key rotation successful for user $USER_NAME"
      fi
   else
      echo "Key rotation not needed (newest key age: $ddiff days)"
   fi
   echo
done

