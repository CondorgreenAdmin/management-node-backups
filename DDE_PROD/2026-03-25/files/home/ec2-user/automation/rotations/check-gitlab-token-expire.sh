#!/bin/bash

cd ~/automation/rotations

DL="arnulf.hanauer@vcontractor.co.za, yusuf.pinn@vcontractor.co.za, blaine.simpson@vcontractor.co.za, michaelalex.dirks@vcontractor.co.za"
#DL="arnulf.hanauer@vcontractor.co.za"

ACT_DTE=$(date -d "`cat ~/keys/gitlab_token_expiry.dat`" +"%s")

NOW_DTE=$(date +"%s")

ddiff=$(( ( $ACT_DTE - $NOW_DTE ) / 86400 ))

if [[ $ddiff -lt 10 ]];then

	echo -e "Good day support\n\nThe current GITLAB Access Token will expire in $ddiff days.\n\nThis Gitlab Access Token allows the automatic AWS key rotations every 90 days as required by Vodacom policy. This Gitlab access token needs to be manually rotated iwithin Gitlab at least one per year\n\nPlease login to the Condorgreen GitLab account and locate the Settings/Access tokens section. Please rotate the Access Token [PROGRAMMATIC_UPDATE]\n\nPlease collect the new password that will be displayed post the rotate request.\nThis password will need to be updated on both the K8S Management Nodes for DDE (PROD & UAT) in the ~/keys/gitlab_cg_<>.dat file for Condorgreen\n\nYou need to repeat the same process for the Vodacom GitLab account. Login to Vodacom GitLab vodacomsa/DDE, rotate that Access Token as well, save the password and insert it on the Prod Management Node only in the ~/keys/gitlab_vc_<>.dat file.\n\nWhen still in the GitLab screen after having changed the Access Tokea, hover over the Expires value and it will show the next Token expiry date.\nPlease update the K8S Management node file ~/keys/gitlab_token_expiry.dat with the new date so you can be alerted/informed of the next required GitLab Access Token rotation.\n\n\nFailure to update either of the two Access Tokens and the expiry date file will render the DDE CI/CD pipeline unusable and code will not be able to be pushed.\n\nPlease follow these instructions diligently to avoid unnecessary stress.\n\nPlease be aware that the Token is managed voa the Prod K8S only but the tokens need to be shared between both Prod & UAT otherwise Prod might wprk but UAT doesn't. Understand its a single Token access key to the Gitlab environments, there is only on Gitlab.\n\nGood luck." | mutt -s "GITLAB Token rotation required in the DDE PROD & UAT environments." -- $DL
fi
echo

