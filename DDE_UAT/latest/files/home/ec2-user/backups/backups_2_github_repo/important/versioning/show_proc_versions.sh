
#!/bin/bash

#kubectl get pods > $$kubedata

#llist="client-depl dde-depl loader-depl worker-depl"

touch $$temp
rm $$temp


#echo "Object Release Published_timestamp Version Running_timestamp Version" >> $$tem
#echo "Stored#Procedures 1.1.123 2121321321 29#Oct#2024 "  >> $$temp

updatedDate=$(mysql --defaults-extra-file=~/dde-sox.cnf --defaults-group-suffix=1 -e "CALL util_get_recent_update('DDE-prd')" --batch --raw -s)
unixDate=$(date -d "$updatedDate" +%s)
updateDateString=$(echo $updatedDate | sed "s/ /#/g")

releaseInfo=$(cat ~/versioning/sp_deployments_version_master | awk '{print $1,$3"#"$4,$2}')

CRQ="###"

#check if there was a change from yesterday and today
LAST_ENTRY=$(~/versioning/scripts/get_last_version.sh "2" .)

RUN_VERSION=$(echo $releaseInfo | awk '{print $1}')
LAST_RUN_VERSION=$(echo $LAST_ENTRY | awk '{print $3}' | head -1)

if [[ $LAST_RUN_VERSION != $RUN_VERSION ]]; then
      # where to get the CRQ number
      CRQ="$(aws s3 cp s3://dev-dopadde-share/deployment_artifacts/CRQ.txt - | grep PROC | awk -F "=" '{print $2}')"
      #CRQ="$(cat ~/versioning/scripts/downloaded/CRQ.txt | tail -1 | awk '{print $2}')"
fi

echo -n "Stored#Procedures#&#Functions $releaseInfo $updateDateString $unixDate $CRQ" > $$temp

cat $$temp
echo

rm $$temp

