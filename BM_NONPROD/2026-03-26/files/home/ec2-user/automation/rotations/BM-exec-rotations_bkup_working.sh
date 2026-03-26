#!/bin/bash

export PATH=/usr/local/bin:$PATH

cd ~/automation/rotations

OPT=""
USR=$1
#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, michaelalex.dirks@vcontractor.co.za"
DL="michaelalex.dirks@vcontractor.co.za"
#DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)

SECRET_ID="nonprod_bm_accesskeys"

timestamp=$(date +"%Y%m%d-%H%M%S")
temp_file="/tmp/rotated_keys_$timestamp.txt"

trap "rm -f '$temp_file'" EXIT

if [[ $USR == "nonprod_bm_app_user" ]]; then
   OPT="APP"
fi

if [[ $USR == "nonprod_bm_gitlab_ci" ]]; then
   OPT="GIT"
fi
if [[ $USR == "nonprod_bm_cli_access" ]]; then
   OPT="CLI"
fi

if [[ $USR == "nonprod_bm_eks_control" ]]; then
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

# Step 4: Post-rotation logic based on type
case $OPT in
    "EKS")
        OUT="/home/ec2-user/.aws/credentials"
        PROFILE="default"
        TMP="/tmp/credentials.tmp"
        DTE2=$(date +"%Y%m%d-%H%M%S")

        # Backup original credentials file
        cp "$OUT" "$OUT.$DTE2"

        # Use awk to edit the profile's keys in place
        awk -v profile="[$PROFILE]" \
            -v key="$NEW_ACCESS_KEY_ID" \
            -v secret="$NEW_SECRET_ACCESS_KEY" '
            BEGIN { in_profile=0 }
            {
                if ($0 ~ /^\[/) {
                    in_profile = ($0 == profile)
                }
                if (in_profile && $0 ~ /^aws_access_key_id/) {
                    print "aws_access_key_id = " key
                    next
                }
                if (in_profile && $0 ~ /^aws_secret_access_key/) {
                    print "aws_secret_access_key = " secret
                    next
                }
                print
        }
        ' "$OUT" > "$TMP" && mv "$TMP" "$OUT"
        echo "$PROFILE updated" | tee -a ~/keys/status.log
        sleep 20
        # Read current secret value
        CURRENT_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text)

        # Changing profile back to actual name of profile and not "default"
        PROFILE=$USR
        # Update only the relevant profile in the JSON
        UPDATED_SECRET=$(echo "$CURRENT_SECRET" | \
          jq --arg profile "$PROFILE" \
             --arg id "$NEW_ACCESS_KEY_ID" \
             --arg secret "$NEW_SECRET_ACCESS_KEY" \
             '.aws_credentials[$profile].ACCESS_KEY_ID = $id | .aws_credentials[$profile].SECRET_ACCESS_KEY = $secret')

        # Write updated JSON back to Secrets Manager
        aws secretsmanager put-secret-value \
          --secret-id "$SECRET_ID" \
          --secret-string "$UPDATED_SECRET"

        echo "Secrets Manager updated with new AWS credentials for $PROFILE." | tee -a ~/keys/status.log
        echo "nonprod_bm_eks_control rotated" > "$temp_file"
       ;;

    "CLI")
        OUT="/home/ec2-user/.aws/credentials"
        PROFILE="nonprod_bm_cli_access"
        TMP="/tmp/credentials.tmp"
        DTE2=$(date +"%Y%m%d-%H%M%S")

        # Backup original credentials file
        cp "$OUT" "$OUT.$DTE2"

        # Use awk to edit the profile's keys in place
        awk -v profile="[$PROFILE]" \
            -v key="$NEW_ACCESS_KEY_ID" \
            -v secret="$NEW_SECRET_ACCESS_KEY" '
            BEGIN { in_profile=0 }
            {
                if ($0 ~ /^\[/) {
                    in_profile = ($0 == profile)
                }
                if (in_profile && $0 ~ /^aws_access_key_id/) {
                    print "aws_access_key_id = " key
                    next
                }
                if (in_profile && $0 ~ /^aws_secret_access_key/) {
                    print "aws_secret_access_key = " secret
                    next
                }
                print
        }
        ' "$OUT" > "$TMP" && mv "$TMP" "$OUT"
        echo "$PROFILE updated" | tee -a ~/keys/status.log
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
        echo "nonprod_bm_cli_access rotated" > "$temp_file"
        ;;
    "GIT")
        # --------------------------- Automated Git process to be added ----------------------------------------
        echo "This is a git key. Please do this manually"
        OUT="/home/ec2-user/.aws/credentials"
        PROFILE="nonprod_bm_gitlab_ci"
        TMP="/tmp/credentials.tmp"
        DTE2=$(date +"%Y%m%d-%H%M%S")

        # Backup original credentials file
        cp "$OUT" "$OUT.$DTE2"

        # Use awk to edit the profile's keys in place
        awk -v profile="[$PROFILE]" \
            -v key="$NEW_ACCESS_KEY_ID" \
            -v secret="$NEW_SECRET_ACCESS_KEY" '
            BEGIN { in_profile=0 }
            {
                if ($0 ~ /^\[/) {
                    in_profile = ($0 == profile)
                }
                if (in_profile && $0 ~ /^aws_access_key_id/) {
                    print "aws_access_key_id = " key
                    next
                }
                if (in_profile && $0 ~ /^aws_secret_access_key/) {
                    print "aws_secret_access_key = " secret
                    next
                }
                print
        }
        ' "$OUT" > "$TMP" && mv "$TMP" "$OUT"

        echo "$PROFILE updated" | tee -a ~/keys/status.log
        # Read current secret value
        CURRENT_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text)

        # Update only the relevant profile in the JSON
        UPDATED_SECRET=$(echo "$CURRENT_SECRET" | \
          jq --arg profile "$PROFILE" \
             --arg id "$NEW_ACCESS_KEY_ID" \
             --arg secret "$NEW_SECRET_ACCESS_KEY" \
             '.aws_credentials[$profile].ACCESS_KEY_ID = $id | .aws_credentials[$profile].SECRET_ACCESS_KEY = $secret')

        # Write updated JSON back to Secrets Manager
        aws secretsmanager put-secret-value \
          --secret-id "$SECRET_ID" \
          --secret-string "$UPDATED_SECRET"

        echo "Secrets Manager updated with new AWS credentials for $PROFILE." | tee -a ~/keys/status.log
        echo "nonprod_bm_gitlab_ci rotated" > "$temp_file"
        ;;
    "APP")
        #for envronment in dev-product-catalog qa-product-catalog uat-product-catalogue
	#do
                ENCODED_VALUE_KEY_ID=$(echo -n "$NEW_ACCESS_KEY_ID" | base64)
                ENCODED_VALUE_ACCESS_KEY=$(echo -n "$NEW_SECRET_ACCESS_KEY" | base64)
                SECRET_NAME="aws-secret"
                #NAMESPACE="$environment"
		NAMESPACE="uat-product-catalogue"

                # Patch the secret with the new data
                kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/accessKeyID\", \"value\": \"$ENCODED_VALUE_KEY_ID\"}]" | tee -a ~/keys/status.log
                err1=$?
                kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/secretAccessKey\", \"value\": \"$ENCODED_VALUE_ACCESS_KEY\"}]" | tee -a ~/keys/status.log
                err2=$?

                if [[ $err1 == 0 && $err2 == 0 ]]; then
                    echo "$SECRET_NAME updated" | tee -a ~/keys/status.log
                    kubectl delete pod -l app=api -n "$NAMESPACE" | tee -a ~/keys/status.log
                    sleep 5
                    kubectl delete pod -l app=worker -n "$NAMESPACE" | tee -a ~/keys/status.log
                    sleep 5
                    kubectl delete pod -l app=client -n "$NAMESPACE" | tee -a ~/keys/status.log
                    sleep 5
                    echo "PODS (dde, worker and loader) have been restarted" | tee -a ~/keys/status.log
                    kubectl get pods -A | tee -a ~/keys/status.log
                else
                    echo "There was an error during the EKS secret update" | tee -a ~/keys/status.log
                    echo "" | tee -a ~/keys/status.log
                    hostname=$(hostname)
                    echo -e "kubectl patch secret: $SECRET_NAME\n\nerr1=$err1\nerr2=$err2\n" | mutt -s "ERROR: $hostname kubectl secret updates failed: Please investigate" -- $DL
                    exit 8
                fi
        #done
        # Update the aws credentials file
        OUT="/home/ec2-user/.aws/credentials"
        PROFILE="nonprod_bm_app_user"
        TMP="/tmp/credentials.tmp"
        DTE2=$(date +"%Y%m%d-%H%M%S")

        # Backup original credentials file
        cp "$OUT" "$OUT.$DTE2"

        # Use awk to edit the profile's keys in place
        awk -v profile="[$PROFILE]" \
            -v key="$NEW_ACCESS_KEY_ID" \
            -v secret="$NEW_SECRET_ACCESS_KEY" '
            BEGIN { in_profile=0 }
            {
                if ($0 ~ /^\[/) {
                    in_profile = ($0 == profile)
                }
                if (in_profile && $0 ~ /^aws_access_key_id/) {
                    print "aws_access_key_id = " key
                    next
                }
                if (in_profile && $0 ~ /^aws_secret_access_key/) {
                    print "aws_secret_access_key = " secret
                    next
                }
                print
        }
        ' "$OUT" > "$TMP" && mv "$TMP" "$OUT"
        echo "$PROFILE updated" | tee -a ~/keys/status.log
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
        echo "nonprod_bm_app_user rotated" > "$temp_file"
        ;;
esac

echo "" | tee -a ~/keys/status.log
sync
echo "Rotation complete. Please update your credentials with the new access key."
{
        echo "BM NONPROD Keys rotated. Please see below for details."
        echo
        cat "$temp_file"
} | mutt -s "NONPROD BM - Key rotation" -a "$temp_file" -- $DL
