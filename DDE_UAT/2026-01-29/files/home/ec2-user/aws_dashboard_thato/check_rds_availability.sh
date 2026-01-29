#!/bin/bash

# AWS RDS Instance Identifier
RDS_INSTANCE_ID="dopa-dde-uat-writer"

STATUS_FILE="./rds-status.txt"

#DL="thato.mokoena@condorgreen.com, michael.dirks@condorgreen.com, arnulf.hanauer@condorgreen.com, raeesah.khan@condorgreen.com, lukhanyo.vakele@condorgreen.com"
DL="thato.mokoena@condorgreen.com,raeesah.khan@condorgreen.com"

EMAIL_SUBJECT="URGENT: RDS Instance Down ALERT!"
EMAIL_BODY= 

# Check RDS instance status
#STATUS=$(aws rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE_ID" --query 'DBInstances[0].DBInstanceStatus' --output text)

if [[ -f "$STATUS_FILE" ]]; then
	STATUS=$(cat $STATUS_FILE)
else
	STATUS="unknown"
fi

# if instnace status != available, send alert email
if [[ "$STATUS" != "available" ]]; then
	#echo "$EMAIL_BODY" | mutt -s "$EMAIL_SUBJECT" "$DL"
	echo "ALERT: The RDS Instance($RDS_INSTANCE_ID) is down!"
else 
	echo "We are crushing it :)"
fi
