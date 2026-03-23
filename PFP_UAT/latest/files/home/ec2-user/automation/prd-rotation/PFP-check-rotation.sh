#!/bin/bash

cd ~/automation/rotations


#for user in prod_pfp_github_ci prod_pfp_app_user prod_pfp_cli_access prod_pfp_eks_control
for user in prod_pfp_github_ci
#for user in prod_pfp_app_user prod_pfp_cli_access prod_pfp_eks_control
do

   #Using the Github/Gitlab user to trigger AWS key rotations
   USER_NAME=$user
   echo $user
   INACTIVE_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" | jq -r '.AccessKeyMetadata[] | select(.Status == "Inactive") | .CreateDate')

   ACTIVE_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" | jq -r '.AccessKeyMetadata[] | select(.Status == "Active") | .CreateDate')

   INACT_DTE=$(date -d $INACTIVE_KEYS +"%s")
   echo "INACT_DTE = $INACT_DTE"
   ACT_DTE=$(date -d $ACTIVE_KEYS +"%s")
   echo "ACT_DTE = $ACT_DTE"
   NOW_DTE=$(date +"%s")
   echo "NOW_DTE = $NOW_DTE"

   dmax=$(( $ACT_DTE > $INACT_DTE ? $ACT_DTE : $INACT_DTE ))
   ddiff=$(( ( $NOW_DTE - $dmax ) / 86400 ))

   if [ $ddiff -gt 83 ];then

      if [[ $user == "prod_pfp_github_ci" ]];then	   
         ./PFP-exec-rotation.sh GIT
      fi	 
      if [[ $user == "prod_pfp_app_user" ]];then	   
         ./PFP-exec-rotation.sh APP
      fi
      if [[ $user == "prod_pfp_cli_access" ]];then	   
         ./PFP-exec-rotation.sh CLI
      fi
      if [[ $user == "prod_pfp_eks_control" ]];then	   
         ./PFP-exec-rotation.sh EKS
      fi

      echo "AWS key age for user $USER_NAME was $ddiff" | mutt -s "AWS keys rotation executed for the PFP PROD environment" "arnulf.hanauer@vcontractor.co.za"
      echo "AWS key age for user $USER_NAME was $ddiff" 
   else   
      echo "AWS key age for user $USER_NAME was $ddiff" 
   fi
   echo

done

