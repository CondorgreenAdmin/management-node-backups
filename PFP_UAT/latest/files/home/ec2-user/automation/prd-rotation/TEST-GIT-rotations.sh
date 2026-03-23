#~/bin/bash

cd ~/automation/rotations

ulist=""
OPT=$1
DL="arnulf.hanauer@vcontractor.co.za"

if [[ $1 == "GIT" ]];then
   ulist="prod_pfp_github_ci"
   PVTOKEN_CG=$(cat ~/keys/github_cg_prod.dat)
   OWNER="CondorgreenAdmin"
   REPO="VCCRM"
fi

DTE=$(date +"%Y-%m-%d %H:%M:%S")

for u in $ulist
do

   USER_NAME="$u"

   NEW_ACCESS_KEY_ID="TEST"
   NEW_SECRET_ACCESS_KEY="SECRET_TEST"

   echo "Date: "`date +"%Y-%m-%d %H:%M:%S"`
   echo "User Name: $USER_NAME"
   echo "New Access Key ID: $NEW_ACCESS_KEY_ID" 
   echo "New Secret Access Key: $NEW_SECRET_ACCESS_KEY"

   case $OPT in
        "GIT") ### fixed VC missing Gitlab, update of the secret moved to the app_user, just require api tokens for the CG Gitlab account. Only function is GitLab access to trigger lambda


               # Set variables
               ###GITHUB_TOKEN=$PVTOKEN_CG
               SECRET_NAME="AWS_TEST_ID"
	       SECRET_VALU="AWS_TEST_SECRET"
               NEW_SECRET_NAME_VALUE=$NEW_ACCESS_KEY_ID
	       NEW_SECRET_VALU_VALUE=$NEW_SECRET_ACCESS_KEY

               # Get repository public key
               PUBKEY_RESPONSE=$(curl -s -H "Authorization: token $PVTOKEN_CG" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/secrets/public-key")

echo "PUBKEY+RESPONSE="$PUBKEY_RESPONSE	       

               # Extract key_id and public key
               KEY_ID=$(echo "$PUBKEY_RESPONSE" | jq -r '.key_id')
               PUBLIC_KEY=$(echo "$PUBKEY_RESPONSE" | jq -r '.key')
echo "ID=$KEY_ID"	       
echo "KEY=$PUBLIC_KEY"	       

               # Encrypt the secret using the public key
               ENCODED_SECRET_NAME=$(`python3 encrypt.py "$PUBLIC_KEY" "$NEW_SECRET_NAME_VALUE"`) 
echo "ENCODED_SECRET_NAME="$ENCODED_SECRET_NAME	       
               ENCODED_SECRET_VALU=$(`python3 encrypt.py "$PUBLIC_KEY" "$NEW_SECRET_NAME_VALUE"`) 
echo "ENCODED_SECRET_VALU="$ENCODED_SECRET_VALU	       

	       

               echo "CURL next: Updating CG GitHub ACCESS_KEY" 

               curl -s -X PUT -H "Authorization: token $PVTOKEN_CG" \
  -H "Content-Type: application/json" \
  -d "{\"encrypted_value\":\"$ENCODED_SECRET_NAME\", \"key_id\":\"$KEY_ID\"}" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/secrets/$SECRET_NAME"
	       RES1=$?
	       echo "TOKEN update = $RES1"
               echo
               echo "CURL next: Updating CG GitHub ACCESS_SECRET" 

               curl -s -X PUT -H "Authorization: token $PVTOKEN_CG" \
  -H "Content-Type: application/json" \
  -d "{\"encrypted_value\":\"$ENCODED_SECRET_VALU\", \"key_id\":\"$KEY_ID\"}" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/secrets/$SECRET_VALU"
	       RES2=$?
	       echo "SECRET update = $RES2"

	       if [[ $RES1 -gt 0 || $RES2 -gt 0 ]];then
		       echo "Error during update of GitHub Key/Password - Please investigate soonest"
		       #echo "Error during update of GitHub Key/Password - Please investigate soonest:\nRC1=$RES1\nRC2=$RES2" | mutt -s "PFP AWS & GitHub key rotation error" -- $DL
               else
		       echo "Updating of the GitHub Key and Secret successful"
	       fi   

               echo
           ;;

   esac

done

echo ""

