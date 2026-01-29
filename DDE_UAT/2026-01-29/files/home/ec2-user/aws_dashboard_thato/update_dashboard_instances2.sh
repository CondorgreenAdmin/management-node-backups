#!/bin/bash
 
# Set AWS region
AWS_REGION="af-south-1"
 
# Fetch the latest EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId, PrivateDnsName]' --output text --region "$AWS_REGION" > aws-instances.txt
 
# Extract the last two instances (last 2 because testing in uat)
NEW_INSTANCE_IDS=($(awk '{print $1}' aws-instances.txt | tail -n 2))
NEW_PRIVATE_DNS=($(awk '{print $2}' aws-instances.txt | tail -n 2))
 
echo "----- New Instances ------"
echo "New Instance IDs: ${NEW_INSTANCE_IDS[@]}"
echo "New Private DNS Names: ${NEW_PRIVATE_DNS[@]}"
 
# CloudWatch Dashboard
DASHBOARD_NAME="Compliance_Report"
 
# Get the current dashboard 
aws cloudwatch get-dashboard --dashboard-name "$DASHBOARD_NAME" --query 'DashboardBody' --output text > dashboard2.json
 
# Extract current instance details from JSON and get the first two 
CURRENT_INSTANCE_IDS=($(jq -r '.widgets[].properties.metrics[][] | select(type == "string") | select(startswith("i-"))' dashboard2.json | head -n 2))
CURRENT_PRIVATE_DNS=($(jq -r '.widgets[].properties.metrics[][] | select(type == "string") | select(contains("compute.internal"))' dashboard2.json | head -n 2))
 
echo "----- Current Instances ------"
echo "Current Instance IDs: ${CURRENT_INSTANCE_IDS[@]}"
echo "Current Private DNS Names: ${CURRENT_PRIVATE_DNS[@]}"
 
# Check if the first two instances are different
if [[ "${CURRENT_INSTANCE_IDS[*]}" == "${NEW_INSTANCE_IDS[*]}" && "${CURRENT_PRIVATE_DNS[*]}" == "${NEW_PRIVATE_DNS[*]}" ]]; then
    echo "No changes detected. CloudWatch dashboard update is not needed."
    exit 0
else
    echo "Changes detected. Updating CloudWatch dashboard..."
	
	for ((i=0; i<2; i++)); do
    	OLD_ID=${CURRENT_INSTANCE_IDS[i]}
    	NEW_ID=${NEW_INSTANCE_IDS[i]}
    	OLD_DNS=${CURRENT_PRIVATE_DNS[i]}
    	NEW_DNS=${NEW_PRIVATE_DNS[i]}

    	echo "Replacing $OLD_ID with $NEW_ID"
    	echo "Replacing $OLD_DNS with $NEW_DNS"

    	# Replace all occurrences of the instance IDs and DNS names in the JSON
    	sed -i "s/$OLD_ID/$NEW_ID/g" dashboard2.json
    	sed -i "s/$OLD_DNS/$NEW_DNS/g" dashboard2.json
	done		

fi

aws cloudwatch put-dashboard --dashboard-name "$DASHBOARD_NAME" --dashboard-body file://dashboard2.json
  

echo "CloudWatch dashboard updated successfully."

