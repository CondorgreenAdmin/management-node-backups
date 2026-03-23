#~/bin/bash

cd ~/automation/rotations

ulist=""
OPT=$1
DL="arnulf.hanauer@vcontractor.co.za"

if [[ $1 == "APP" ]];then
   ulist="prod_pfp_app_user"
fi
if [[ $1 == "GIT" ]];then
   ulist="prod_pfp_github_ci"
   PVTOKEN_CG=$(cat ~/keys/github_cg_prod.dat)
   OWNER="CondorgreenAdmin"
   REPO="VCCRM"
   #PVTOKEN_VC=$(cat keys/gitlab_vc_prod.dat)
   #ACCNT_CG="60949717"
   #ACCNT_VC="62841362"
fi
if [[ $1 == "CLI" ]];then
   ulist="prod_pfp_cli_access"
fi
if [[ $1 == "EKS" ]];then
   ulist="prod_pfp_eks_control"
fi

DTE=$(date +"%Y-%m-%d %H:%M:%S")

if [[ "A"$ulist == "A" ]];then
   echo
   echo "Command: PFP-exec-rotation.sh < APP | GIT | CLI | EKS >"
   echo
   echo "No parameters supplied!!!  Nothing to do"
   echo
   exit 8
fi

for u in $ulist
do

   USER_NAME="$u"

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

   #Options requiring post-processing to update outside stores

   case $OPT in
        "GIT") ### fixed VC missing Gitlab, update of the secret moved to the app_user, just require api tokens for the CG Gitlab account. Only function is GitLab access to trigger lambda


               # Set variables
               ###GITHUB_TOKEN=$PVTOKEN_CG
               SECRET_NAME="AWS_PROD_ACCESS_KEY_ID"
	       SECRET_VALU="AWS_PROD_SECRET_ACCESS_KEY"
               #SECRET_NAME="AWS_TEST_ID"
	       #SECRET_VALU="AWS_TEST_SECRET"
               NEW_SECRET_NAME_VALUE=$NEW_ACCESS_KEY_ID
	       NEW_SECRET_VALU_VALUE=$NEW_SECRET_ACCESS_KEY
               #NEW_SECRET_NAME_VALUE="JUST_TESTING"
	       #NEW_SECRET_VALU_VALUE="DUMMY321bdbsha++--//##$$$"

	       echo "Authenticating with GitHub token" | tee -a ~/keys/status.log
               echo "$PVTOKEN_CG" | gh auth login --with-token
               if [[ $? -gt 0 ]];then
		  echo "Failed to authenticate with GitHub PAT token" | tee -a ~/keys/status.log
	       else	 
		  echo "Successful authenticate with GitHub PAT token" | tee -a ~/keys/status.log
                  echo "Updating CG GitHub ACCESS_KEY" | tee -a ~/keys/status.log
                  gh secret set $SECRET_NAME --body "$NEW_SECRET_NAME_VALUE" --repo "${OWNER}/${REPO}" 
	          RES1=$?
	          echo "TOKEN update RC= $RES1" | tee -a ~/keys/status.log
                  echo
                  echo "Updating CG GitHub ACCESS_SECRET" | tee -a ~/keys/status.log
                  gh secret set $SECRET_VALU --body "$NEW_SECRET_VALU_VALUE" --repo "${OWNER}/${REPO}" 
	          RES2=$?
	          echo "SECRET update RC= $RES2" | tee -a ~/keys/status.log

	          if [[ $RES1 -gt 0 || $RES2 -gt 0 ]];then
		       echo "Error during update of GitHub Key/Password - Please investigate soonest" | tee -a keys/status.log
		       echo "Error during update of GitHub Key/Password - Please investigate soonest:\nRC1=$RES1\nRC2=$RES2" | mutt -s "PFP AWS & GitHub key rotation error" -- $DL
                  else
		       echo "Updating of the GitHub Key and Secret successful" | tee -a ~/keys/status.log
	          fi   
               fi
               echo
           ;;

        "EKS") ### EKS is the owner of the clusterm CLI only has admin rights
               OUT="/home/ec2-user/.aws/credentials"
               DTE2=$(date +"%Y%m%d-%H%M%S")
               cp $OUT $OUT.$DTE2
               echo "[default]" > $OUT
               echo "aws_access_key_id = $NEW_ACCESS_KEY_ID" >> $OUT
               echo "aws_secret_access_key = $NEW_SECRET_ACCESS_KEY" >> $OUT
               echo ".aws/credentials updated" | tee -a ~/keys/status.log
           ;;

        "CLI") ### CLI only has a full admin function, no EKS control
               OUT="/home/ec2-user/.aws/credentials"
               #DTE2=$(date +"%Y%m%d-%H%M%S")
               #cp $OUT $OUT.$DTE2
	       echo "" >> $OUT
               echo "[prod_pfp_cli_access]" >> $OUT
               echo "aws_access_key_id = $NEW_ACCESS_KEY_ID" >> $OUT
               echo "aws_secret_access_key = $NEW_SECRET_ACCESS_KEY" >> $OUT
               echo ".aws/credentials updated" | tee -a ~/keys/status.log
           ;;

        "APP") ### This controls the S3 access for the app
               # AWS secret updates: Encode the value in Base64
               ENCODED_VALUE_KEY_ID=$(echo -n "$NEW_ACCESS_KEY_ID" | base64)
               ENCODED_VALUE_ACCESS_KEY=$(echo -n "$NEW_SECRET_ACCESS_KEY" | base64)
               SECRET_NAME="aws-secret"
               NAMESPACE="default"

               # Patch the secret with the new data
               kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/accessKeyID\", \"value\": \"$ENCODED_VALUE_KEY_ID\"}]" | tee -a ~/keys/status.log
               echo | tee -a ~/keys/status.log

               kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/secretAccessKey\", \"value\": \"$ENCODED_VALUE_ACCESS_KEY\"}]" | tee -a ~/keys/status.log
               echo | tee -a ~/keys/status.log
	       #Restart 3x PODS api, worker
               kubectl delete pod -l app=api | tee -a ~/keys/status.log
               sleep 5
               kubectl delete pod -l app=worker | tee -a ~/keys/status.log
               sleep 5
               kubectl get pods | tee -a ~/keys/status.log
               echo
	   ;;
   esac

done

echo "" | tee -a ~/keys/status.log

