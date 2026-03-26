#!/bin/bash

export PATH=/usr/local/bin:$PATH

cd ~/automation/rotations

OPT=""
USR=$1
#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, michaelalex.dirks@vcontractor.co.za"
DL="michaelalex.dirks@vcontractor.co.za"
#DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)

SECRET_ID="preprod_bm_accesskeys"

timestamp=$(date +"%Y%m%d-%H%M%S")
temp_file="/tmp/rotated_keys_$timestamp.txt"

trap "rm -f '$temp_file'" EXIT

if [[ $USR == "preprod_bm_app_user" ]]; then
   OPT="APP"
fi

if [[ $USR == "preprod_bm_gitlab_ci" ]]; then
   OPT="GIT"
fi
if [[ $USR == "preprod_bm_cli_access" ]]; then
   OPT="CLI"
fi

if [[ $USR == "preprod_bm_eks_control" ]]; then
   OPT="EKS"
fi

DTE=$(date +"%Y-%m-%d %H:%M:%S")

if [[ "A"$USR == "A" ]]; then
   echo
   echo "Command: BM-exec-rotation.sh <AWS IAM User Name>"
   echo
   echo "No parameters supplied!!!  Nothing to do"
   echo
   exit 8
fi

USER_NAME="$USR"

### Need to fix ---- Only delete old key if there are more two keys

# Step 1: Cleanup Inactive keys
echo "Checking for existing inactive keys for user: $USER_NAME"
INACTIVE_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" | jq -r '.AccessKeyMetadata[] | select(.Status == "Inactive") | .AccessKeyId')

# Delete all inactive keys before proceeding
for KEY_ID in $INACTIVE_KEYS; do
  echo "Deleting inactive key: $KEY_ID"
  aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$KEY_ID"
done

# Step 2: Create new access key
echo "Creating a new access key for user: $USER_NAME"
NEW_KEY_JSON=$(aws iam create-access-key --user-name "$USER_NAME")

NEW_ACCESS_KEY_ID=$(echo "$NEW_KEY_JSON" | jq -r '.AccessKey.AccessKeyId')
NEW_SECRET_ACCESS_KEY=$(echo "$NEW_KEY_JSON" | jq -r '.AccessKey.SecretAccessKey')

#Check the key password has sufficient length
KLEN1=$(echo $NEW_ACCESS_KEY_ID | wc -c)
KLEN2=$(echo $NEW_SECRET_ACCESS_KEY | wc -c)

if [[ $KLEN1 -lt 20 || $KLEN2 -lt 32 ]]; then
  echo "Invalid length detected for either the ID or KEY - Aborting programme"
  echo "KLEN1 : ${KLEN1}"
  echo "KLEN2 : ${KLEN2}"
  exit 8
fi

echo "Date: $DTE" | tee -a ~/keys/status.log
echo "User Name: $USER_NAME" | tee -a ~/keys/status.log
echo "New Access Key ID: $NEW_ACCESS_KEY_ID" | tee -a ~/keys/status.log
echo "New Secret Access Key: $NEW_SECRET_ACCESS_KEY" | tee -a ~/keys/status.log

# Step 3: List existing keys and deactivate the old key
OLD_ACCESS_KEY_ID=$(aws iam list-access-keys --user-name "$USER_NAME" | jq -r '.AccessKeyMetadata[] | select(.AccessKeyId != "'"$NEW_ACCESS_KEY_ID"'").AccessKeyId')

if [ -n "$OLD_ACCESS_KEY_ID" ]; then
  echo "Deactivating old access key: $OLD_ACCESS_KEY_ID" | tee -a ~/keys/status.log
  aws iam update-access-key --user-name "$USER_NAME" --access-key-id "$OLD_ACCESS_KEY_ID" --status Inactive
fi

OUT="/home/ec2-user/.aws/credentials"
TMP="/tmp/credentials.tmp"
DTE2=$(date +"%Y%m%d-%H%M%S")
# Backup original credentials file
cp "$OUT" "$OUT.$DTE2"

# Step 4: Post-rotation logic based on type
case $OPT in
    "CLI")
        #PROFILE="nonprod_bm_cli_access"
        PROFILE=$USR

        # Setting the profile nonprod_bm_cli_access
        aws configure set aws_access_key_id $NEW_ACCESS_KEY_ID --profile $PROFILE
        aws configure set aws_secret_access_key $NEW_SECRET_ACCESS_KEY --profile $PROFILE

        # Setting the default
	      aws configure set aws_access_key_id $NEW_ACCESS_KEY_ID
        aws configure set aws_secret_access_key $NEW_SECRET_ACCESS_KEY

        echo "$PROFILE updated" | tee -a ~/keys/status.log

        # Sleep 10 seconds to allow time for aws to switch off and on the credentials
        sleep 10
        
        ##### Update the secret manager
        # Read current secret value
        CURRENT_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text)

        # Update only the relevant profile in the JSON
        UPDATED_SECRET=$(echo "$CURRENT_SECRET" | \
          jq --arg profile "$PROFILE" \
             --arg id "$NEW_ACCESS_KEY_ID" \
             --arg secret "$NEW_SECRET_ACCESS_KEY" \
             '.aws_credentials[$profile].access_key_id = $id | .aws_credentials[$profile].secret_access_key = $secret')

        # Write updated JSON back to Secrets Manager
        aws secretsmanager put-secret-value \
          --secret-id "$SECRET_ID" \
          --secret-string "$UPDATED_SECRET"

        echo "Secrets Manager updated with new AWS credentials for $PROFILE." | tee -a ~/keys/status.log
        echo "preprod_bm_cli_access rotated" > "$temp_file"
        ;;
    "GIT")
        # --------------------------- Automated Git process to be added ----------------------------------------
        echo "This is a git key. Please do this manually"
        #PROFILE="nonprod_bm_gitlab_ci"
        PROFILE=$USR

        aws configure set aws_access_key_id $NEW_ACCESS_KEY_ID --profile $PROFILE
        aws configure set aws_secret_access_key $NEW_SECRET_ACCESS_KEY --profile $PROFILE

        echo "$PROFILE updated" | tee -a ~/keys/status.log

        # Sleep 10 seconds to allow time for aws to switch off and on the credentials
        sleep 10

        ##### Update the secret manager
        # Read current secret value
        CURRENT_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text)

        # Update only the relevant profile in the JSON
        UPDATED_SECRET=$(echo "$CURRENT_SECRET" | \
          jq --arg profile "$PROFILE" \
             --arg id "$NEW_ACCESS_KEY_ID" \
             --arg secret "$NEW_SECRET_ACCESS_KEY" \
             '.aws_credentials[$profile].access_key_id = $id | .aws_credentials[$profile].secret_access_key = $secret')

        # Write updated JSON back to Secrets Manager
        aws secretsmanager put-secret-value \
          --secret-id "$SECRET_ID" \
          --secret-string "$UPDATED_SECRET"

        echo "Secrets Manager updated with new AWS credentials for $PROFILE." | tee -a ~/keys/status.log
        echo "$PROFILE rotated" > "$temp_file"
        ;;
    "EKS")
        PROFILE=$USR

        aws configure set aws_access_key_id $NEW_ACCESS_KEY_ID --profile $PROFILE
        aws configure set aws_secret_access_key $NEW_SECRET_ACCESS_KEY --profile $PROFILE

        echo "$PROFILE updated" | tee -a ~/keys/status.log
        
        # Sleep 10 seconds to allow time for aws to switch off and on the credentials
        sleep 10

        # Read current secret value
        CURRENT_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text)

        # Changing profile back to actual name of profile and not "default"
        PROFILE=$USR

        # Update only the relevant profile in the JSON
        UPDATED_SECRET=$(echo "$CURRENT_SECRET" | \
          jq --arg profile "$PROFILE" \
             --arg id "$NEW_ACCESS_KEY_ID" \
             --arg secret "$NEW_SECRET_ACCESS_KEY" \
             '.aws_credentials[$profile].access_key_id = $id | .aws_credentials[$profile].secret_access_key = $secret')

        # Write updated JSON back to Secrets Manager
        aws secretsmanager put-secret-value \
          --secret-id "$SECRET_ID" \
          --secret-string "$UPDATED_SECRET"

        echo "Secrets Manager updated with new AWS credentials for $PROFILE." | tee -a ~/keys/status.log
        echo "preprod_bm_eks_control rotated" > "$temp_file"
       ;;

    "APP")
        #for envronment in dev-product-catalog qa-product-catalog uat-product-catalogue
        #do
        ENCODED_VALUE_KEY_ID=$(echo -n "$NEW_ACCESS_KEY_ID" | base64)
        ENCODED_VALUE_ACCESS_KEY=$(echo -n "$NEW_SECRET_ACCESS_KEY" | base64)
        SECRET_NAME="aws-secret"
        #NAMESPACE="$environment"
        NAMESPACE="preprod-product-catalogue"

        # Patch the secret with the new data
        kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/ACCESS_KEY_ID\", \"value\": \"$ENCODED_VALUE_KEY_ID\"}]" | tee -a ~/keys/status.log
        err1=$?
        kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/SECRET_ACCESS_KEY\", \"value\": \"$ENCODED_VALUE_ACCESS_KEY\"}]" | tee -a ~/keys/status.log
        err2=$?

        if [[ $err1 == 0 && $err2 == 0 ]]; then
            echo "$SECRET_NAME updated" | tee -a ~/keys/status.log
            kubectl delete pod -l app=api -n "$NAMESPACE" | tee -a ~/keys/status.log
            sleep 5
            kubectl delete pod -l app=worker -n "$NAMESPACE" | tee -a ~/keys/status.log
            sleep 5
            kubectl delete pod -l app=client -n "$NAMESPACE" | tee -a ~/keys/status.log
            sleep 5
            echo "PODS (api, worker and client) have been restarted" | tee -a ~/keys/status.log
            kubectl get pods -A | tee -a ~/keys/status.log
        else
            echo "There was an error during the EKS secret update" | tee -a ~/keys/status.log
            echo "" | tee -a ~/keys/status.log
            hostname=$(hostname)
            echo -e "kubectl patch secret: $SECRET_NAME\n\nerr1=$err1\nerr2=$err2\n" | mutt -s "ERROR: $hostname kubectl secret updates failed: Please investigate" -- $DL
            exit 8
        fi

        PROFILE=$USR

        aws configure set aws_access_key_id $NEW_ACCESS_KEY_ID --profile $PROFILE
        aws configure set aws_secret_access_key $NEW_SECRET_ACCESS_KEY --profile $PROFILE
        echo "$PROFILE updated" | tee -a ~/keys/status.log
        
        # Sleep 10 seconds to allow time for aws to switch off and on the credentials
        sleep 10 

        # Read current secret value
        CURRENT_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text)

        # Update only the relevant profile in the JSON
        UPDATED_SECRET=$(echo "$CURRENT_SECRET" | \
          jq --arg profile "$PROFILE" \
             --arg id "$NEW_ACCESS_KEY_ID" \
             --arg secret "$NEW_SECRET_ACCESS_KEY" \
             '.aws_credentials[$profile].access_key_id = $id | .aws_credentials[$profile].secret_access_key = $secret')

        # Write updated JSON back to Secrets Manager
        aws secretsmanager put-secret-value \
          --secret-id "$SECRET_ID" \
          --secret-string "$UPDATED_SECRET"

        echo "Secrets Manager updated with new AWS credentials for $PROFILE." | tee -a ~/keys/status.log
        echo "preprod_bm_app_user rotated" > "$temp_file"
        ;;
esac

echo "" | tee -a ~/keys/status.log
sync
echo "Rotation complete. Please update your credentials with the new access key."
{
        echo "BM PREPROD Keys rotated. Please see below for details."
        echo
        cat "$temp_file"
} | mutt -s "PREPROD BM - Key rotation" -a "$temp_file" -- $DL

