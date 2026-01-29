#!/bin/bash
#

export PATH=/usr/local/bin:$PATH

OPT=""
USR=$1
#DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, olwethu.ketwa@vcontractor.co.za, lukhanyo.vakele@vcontractor.co.za"
DL="arnulf.hanauer@vcontractor.co.za"

if [[ $USR == "github-ci" ]];then
   OPT="GIT"
   PVTOKEN_CG=$(cat ~/keys/gitlab_cg_uat.dat)
   PVTOKEN_VC=$(cat ~/keys/gitlab_vc_uat.dat)
   ACCNT_CG="60949717"     #Gitlab project number
   ACCNT_VC="62841362"     #Gitlab project number
fi
if [[ $USR == "dopadde-programmtic-access" ]];then
   OPT="CLI"
fi

DTE=$(date +"%Y-%m-%d %H:%M:%S")

if [[ "A"$USR == "A" ]];then
   echo
   echo "Command: DDE-exec-rotation.sh <AWS IAM User name>"
   echo   
   echo "Since there is No parameter supplied!!!  Nothing to do"
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

# Step 1: Create a new access key
echo "Creating a new access key for user: $USER_NAME"
NEW_KEY_JSON=$(aws iam create-access-key --user-name "$USER_NAME")

NEW_ACCESS_KEY_ID=$(echo "$NEW_KEY_JSON" | jq -r '.AccessKey.AccessKeyId')
NEW_SECRET_ACCESS_KEY=$(echo "$NEW_KEY_JSON" | jq -r '.AccessKey.SecretAccessKey')

#Check the key password has sufficient length
KLEN1=$(echo $NEW_ACCESS_KEY_ID | wc -c)
KLEN2=$(echo $NEW_SECRET_ACCESS_KEY | wc -c)

if [[ $KLEN1 -lt 20 || $KLEN2 -lt 32 ]];then
  echo "Invalid length detected for either the ID or KEY - Aborting programme"
  exit 8
fi

echo "Date: "`date +"%Y-%m-%d %H:%M:%S"` | tee -a ~/keys/status.log
echo "User Name: $USER_NAME" | tee -a ~/keys/status.log
echo "New Access Key ID: $NEW_ACCESS_KEY_ID" | tee -a ~/keys/status.log
echo "New Secret Access Key: $NEW_SECRET_ACCESS_KEY" | tee -a ~/keys/status.log

# Step 2: List existing keys and deactivate the old one
OLD_ACCESS_KEY_ID=$(aws iam list-access-keys --user-name "$USER_NAME" | jq -r '.AccessKeyMetadata[] | select(.AccessKeyId != "'"$NEW_ACCESS_KEY_ID"'").AccessKeyId')

if [ -n "$OLD_ACCESS_KEY_ID" ]; then
  echo "Deactivating old access key: $OLD_ACCESS_KEY_ID"
  aws iam update-access-key --user-name "$USER_NAME" --access-key-id "$OLD_ACCESS_KEY_ID" --status Inactive
fi

#EXECUTE Options requiring post-processing to update outside stores

case $OPT in
   "GIT")

       echo "Updating CG Gitlab ACCESS_KEY" | tee -a ~/keys/status.log
       curl --request PUT \
--header "PRIVATE-TOKEN: $PVTOKEN_CG" \
--header "Content-Type: application/json" \
--data '{
        "value": "'${NEW_ACCESS_KEY_ID}'",
        "protected": true,
        "masked": true,
        "environment_scope": "uat"}' \
"https://gitlab.com/api/v4/projects/$ACCNT_CG/variables/AWS_ACCESS_KEY_ID?filter\[environment_scope\]=uat"
       err1=$?
       echo "Updating CG Gitlab ACCESS_SECRET" | tee -a ~/keys/status.log
       curl --request PUT \
--header "PRIVATE-TOKEN: $PVTOKEN_CG" \
--header "Content-Type: application/json" \
--data '{
        "value": "'${NEW_SECRET_ACCESS_KEY}'",
        "protected": true,
        "masked": true,
        "environment_scope": "uat"}' \
"https://gitlab.com/api/v4/projects/$ACCNT_CG/variables/AWS_SECRET_ACCESS_KEY?filter\[environment_scope\]=uat"
       err2=$?
       echo "Updating VC Gitlab ACCESS_KEY" | tee -a ~/keys/status.log
       curl --request PUT \
--header "PRIVATE-TOKEN: $PVTOKEN_VC" \
--header "Content-Type: application/json" \
--data '{
        "value": "'${NEW_ACCESS_KEY_ID}'",
        "protected": true,
        "masked": true,
        "environment_scope": "uat"}' \
"https://gitlab.com/api/v4/projects/$ACCNT_VC/variables/AWS_ACCESS_KEY_ID?filter\[environment_scope\]=uat"
       err3=$?
       echo "Updating VC Gitlab ACCESS_SECRET" | tee -a ~/keys/status.log
       curl --request PUT \
--header "PRIVATE-TOKEN: $PVTOKEN_VC" \
--header "Content-Type: application/json" \
--data '{
        "value": "'${NEW_SECRET_ACCESS_KEY}'",
        "protected": true,
        "masked": true,
        "environment_scope": "uat"}' \
"https://gitlab.com/api/v4/projects/$ACCNT_VC/variables/AWS_SECRET_ACCESS_KEY?filter\[environment_scope\]=uat"
       err4=$?

       sumerr=$(( err1 + err2 + err3 + err4 ))

       if  [[ $sumerr -eq 0 ]]; then

          # AWS secret updates: Encode the value in Base64
          ENCODED_VALUE_KEY_ID=$(echo -n "$NEW_ACCESS_KEY_ID" | base64 -w 0)
          ENCODED_VALUE_ACCESS_KEY=$(echo -n "$NEW_SECRET_ACCESS_KEY" | base64 -w 0)
          SECRET_NAME="aws-secret"
          NAMESPACE="default"

          echo "Patching secret"
          # Patch the secret with the new data
          kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/accessKeyId\", \"value\": \"$ENCODED_VALUE_KEY_ID\"}]" | tee -a ~/keys/status.log
          err1=$?
          kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/secretAccessKey\", \"value\": \"$ENCODED_VALUE_ACCESS_KEY\"}]" | tee -a ~/keys/status.log
          err2=$?

          if [[ $err1 == 0 && $err2 == 0 ]]; then
             echo "$SECRET_NAME updated" | tee -a ~/keys/status.log
             kubectl delete pod -l app=dde | tee -a ~/keys/status.log
             sleep 5
             kubectl delete pod -l app=worker | tee -a ~/keys/status.log
             sleep 5
             kubectl delete pod -l app=loader | tee -a ~/keys/status.log
             sleep 5
             echo "PODS (dde, worker and loader) have been restarted" | tee -a ~/keys/status.log
             kubectl get pods | tee -a ~/keys/status.log
          else
             echo "There was an error during the EKS secret update" | tee -a ~/keys/status.log
             echo "" | tee -a ~/keys/status.log
             hostname=`hostname`
             echo -e "kubectl patch secret: $SECRET_NAME\n\nerr1=$err1\nerr2=$err2\n" | mutt -s "ERROR: $hostname kubectl secret updates failed: Please investigate" -- $DL
	         exit 8
          fi
       else
          echo "There was an error during the GitLab curl update" | tee -a ~/keys/status.log
          hostname=`hostname`
	      echo -e "Gitlab variable updates:\n\nACCOUNT:$ACCNT_CG\nerr1_cg=$err1\nerr2_cg=$err2\n\nACCOUNT:$ACCNT_VC\nerr3_vc=$err3\nerr4_vc=$err4\n\nPlease investigate." | mutt -s "ERROR: $hostname Gitlab variable updates failed for DDE NONPROD (UAT)" -- $DL
          exit 8
       fi
      ;;

   "CLI")  
       OUT="/home/ec2-user/.aws/credentials"	
       DTE2=$(date +"%Y%m%d-%H%M%S")
       cp $OUT $OUT.$DTE2
       echo "[default]" > $OUT
       echo "aws_access_key_id = $NEW_ACCESS_KEY_ID" >> $OUT
       echo "aws_secret_access_key = $NEW_SECRET_ACCESS_KEY" >> $OUT
       echo ".aws/credentials updated" | tee -a ~/keys/status.log
      ;;
esac	   

echo "" | tee -a ~/keys/status.log
sync
echo "Rotation complete. Please update your credentials with the new access key."
