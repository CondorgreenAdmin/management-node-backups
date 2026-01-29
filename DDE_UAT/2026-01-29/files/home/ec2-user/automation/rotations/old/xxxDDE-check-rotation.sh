#!/bin/bash
#
cd ~/automation/rotations

#Using the Gitlab user to trigger AWS key rotations
USER_NAME="prd-dde-integration"

INACTIVE_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" | jq -r '.AccessKeyMetadata[] | select(.Status == "Inactive") | .CreateDate')

ACTIVE_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" | jq -r '.AccessKeyMetadata[] | select(.Status == "Active") | .CreateDate')

INACT_DTE=$(date -d $INACTIVE_KEYS +"%s")
#echo "INACT_DTE = $INACT_DTE"
ACT_DTE=$(date -d $ACTIVE_KEYS +"%s")
#echo "ACT_DTE = $ACT_DTE"
NOW_DTE=$(date +"%s")
#echo "NOW_DTE = $NOW_DTE"

dmax=$(( $ACT_DTE > $INACT_DTE ? $ACT_DTE : $INACT_DTE ))
ddiff=$(( ( $NOW_DTE - $dmax ) / 86400 ))

#echo "AGE = $ddiff"

if [ $ddiff -gt 84 ];then
   ./DDE-exec-rotation.sh GENERAL
   ./DDE-exec-rotation.sh GIT
   ./DDE-exec-rotation.sh CLI
   echo "AWS key age was $ddiff" | mutt -s "AWS keys rotation executed for the DDE PROD environment" "arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za"
fi

