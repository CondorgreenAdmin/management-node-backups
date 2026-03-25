#!/bin/bash
#

export PATH=/usr/local/bin:$PATH
cd ~/automation/rotations

which kubectl
which curl
echo $PATH

#ulist=""
OPT=""
USR="prd-dde-integration"
DL="arnulf.hanauer@vcontractor.co.za"

if [[ $USR == "prd-dde-integration" ]];then
   OPT="GIT"
   PVTOKEN_CG=$(cat ~/keys/gitlab_cg_prod.dat)
   PVTOKEN_VC=$(cat ~/keys/gitlab_vc_prod.dat)
   ACCNT_CG="60949717"
   ACCNT_VC="62841362"
fi

DTE=$(date +"%Y-%m-%d %H:%M:%S")

if [[ "A"$USR == "A" ]];then
   echo
   echo "Command: DDE-exec-rotate.sh < AWS IAM User Name >"
   echo
   echo "No parameters supplied!!!  Nothing to do"
   echo
   exit 8
fi

USER_NAME="$USR"


case $OPT in
     "GIT")

#         echo "Updating CG Gitlab ACCESS_KEY" | tee -a ~/keys/status.log
#         curl --request PUT \
#--header "PRIVATE-TOKEN: $PVTOKEN_CG" \
#--header "Content-Type: application/json" \
#--data '{
#        "value": "'${NEW_ACCESS_KEY_ID}'",
#        "protected": true,
#        "masked": true,
#        "environment_scope": "prod"}' \
#"https://gitlab.com/api/v4/projects/$ACCNT_CG/variables/AWS_ACCESS_KEY_ID?filter\[environment_scope\]=prod"
#         err1=$?
#         echo "Updating CG Gitlab ACCESS_SECRET" | tee -a ~/keys/status.log
#         curl --request PUT \
#--header "PRIVATE-TOKEN: $PVTOKEN_CG" \
#--header "Content-Type: application/json" \
#--data '{
#        "value": "'${NEW_SECRET_ACCESS_KEY}'",
#        "protected": true,
#        "masked": true,
#        "environment_scope": "prod"}' \
#"https://gitlab.com/api/v4/projects/$ACCNT_CG/variables/AWS_SECRET_ACCESS_KEY?filter\[environment_scope\]=prod"
#         err2=$?
#         echo "Updating VC Gitlab ACCESS_KEY" | tee -a ~/keys/status.log
#         curl --request PUT \
#--header "PRIVATE-TOKEN: $PVTOKEN_VC" \
#--header "Content-Type: application/json" \
#--data '{
#        "value": "'${NEW_ACCESS_KEY_ID}'",
#        "protected": true,
#        "masked": true,
#        "environment_scope": "prod"}' \
#"https://gitlab.com/api/v4/projects/$ACCNT_VC/variables/AWS_ACCESS_KEY_ID?filter\[environment_scope\]=prod"
#         err3=$?
#         echo "Updating VC Gitlab ACCESS_SECRET" | tee -a ~/keys/status.log
#         curl --request PUT \
#--header "PRIVATE-TOKEN: $PVTOKEN_VC" \
#--header "Content-Type: application/json" \
#--data '{
#        "value": "'${NEW_SECRET_ACCESS_KEY}'",
#        "protected": true,
#        "masked": true,
#        "environment_scope": "prod"}' \
#"https://gitlab.com/api/v4/projects/$ACCNT_VC/variables/AWS_SECRET_ACCESS_KEY?filter\[environment_scope\]=prod"
#         err4=$?
#
#	 sumerr=$(( err1 + err2 + err3 + err4 ))
#         
#	 if [[ $sumerr -eq 0 ]]; then
#            # AWS secret updates: Encode the value in Base64
#            ENCODED_VALUE_KEY_ID=$(echo -n "$NEW_ACCESS_KEY_ID" | base64)
#            ENCODED_VALUE_ACCESS_KEY=$(echo -n "$NEW_SECRET_ACCESS_KEY" | base64)
#            SECRET_NAME="aws-secret"
#            NAMESPACE="default"

            # Patch the secret with the new data
#            kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/accessKeyId\", \"value\": \"$ENCODED_VALUE_KEY_ID\"}]" | tee -a ~/keys/status.log
#            err1=$?
#            kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/data/secretAccessKey\", \"value\": \"$ENCODED_VALUE_ACCESS_KEY\"}]" | tee -a ~/keys/status.log
#            err2=$?
#            if [[ $err1 == 0 && $err2 == 0 ]]; then
#               echo "$SECRET_NAME updated" | tee -a ~/keys/status.log
               #Restart 3x PODS (dde, loader, worker
#               kubectl delete pod -l app=dde | tee -a ~/keys/status.log
#               sleep 5
#               kubectl delete pod -l app=worker | tee -a ~/keys/status.log
#               sleep 5
#               kubectl delete pod -l app=loader | tee -a ~/keys/status.log
#               sleep 5
#               echo "PODS (dde, worker and loader) have been restarted" | tee -a ~/keys/status.log
               kubectl get pods > ~/ttt.txt 2>ttt-err.txt
#	    else  
#               echo "There was an error during the EKS secret update" | tee -a ~/keys/status.log
#               echo "" | tee -a ~/keys/status.log
#               hostname=`hostname`
#	       echo -e "kubectl patch secret: $SECRET_NAME\n\nerr1=$err1\nerr2=$err2\n" | mutt -s "ERROR: $hostname kubectl secret updates failed: Please investigate" -- $DL
#	       exit 8
#            fi  
#	 else
#             echo "There was an error during the GitLab curl updates" | tee -a ~/keys/status.log
#             echo "" | tee -a ~/keys/status.log
#             hostname=`hostname`
#             echo -e "Gitlab variable updates:\n\nACCOUNT:$ACCNT_CG\nerr1_cg=$err1\nerr2_cg=$err2\n\nACCOUNT:$ACCNT_VC\nerr3_vc=$err3\nerr4_vc=$err4\n\nPlease investigate." | mutt -s "ERROR: $hostname Gitlab variable updates failed for DDE PROD" -- $DL
#	     exit 8
#	 fi
       ;;

esac


#echo "" | tee -a ~/keys/status.log
#sync  #Flush disk buffers
#echo "Rotation complete. Please update your credentials with the new access key."

