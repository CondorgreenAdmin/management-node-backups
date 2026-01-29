#!/bin/bash

# Set AWS region
AWS_REGION="af-south-1"

# Fetch the latest EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId, PrivateDnsName]' --output text --region "$AWS_REGION" > aws-instances.txt

# Extract the last two instances (last 2 because testing in uat)
NEW_INSTANCE_IDS=($(awk '{print $1}' aws-instances.txt | tail -n 3 ))
NEW_PRIVATE_DNS=($(awk '{print $2}' aws-instances.txt | grep "compute.internal" | tail -n 2 ))

echo "----- New Instances ------"
echo "New Instance IDs: ${NEW_INSTANCE_IDS[@]}}"
echo "New Private DNS Names: ${NEW_PRIVATE_DNS[@]}"

# CloudWatch Dashboard
DASHBOARD_NAME="Compliance_Report"

# Get the current dashboard
aws cloudwatch get-dashboard --dashboard-name "$DASHBOARD_NAME" --query 'DashboardBody' --output text > dashboardTest.json

# Extract current instance details from JSON and get the first two
CURRENT_INSTANCE_IDS=($(jq -r '.widgets[].properties.metrics[][] | select(type == "string") | select(startswith("i-"))' dashboardTest.json | uniq | head -n 3))
CURRENT_PRIVATE_DNS=($(jq -r '.widgets[].properties.metrics[][] | select(type == "string") | select(contains("compute.internal"))' dashboardTest.json | tail -n 2))

echo "----- Current Instances ------"
echo "Current Instance IDs: ${CURRENT_INSTANCE_IDS[@]}"
echo "Current Private DNS Names: ${CURRENT_PRIVATE_DNS[@]}"

# Check if the first two instances are different
if [[ "${CURRENT_INSTANCE_IDS[*]}" == "${NEW_INSTANCE_IDS[*]}" && "${CURRENT_PRIVATE_DNS[*]}" == "${NEW_PRIVATE_DNS[*]}" ]]; then
    echo "No changes detected. CloudWatch dashboard update is not needed."
    exit 0
else
    echo "Changes detected. Updating CloudWatch dashboard..."
fi

for ((i=0; i<3; i++)); do

    OLD_ID=${CURRENT_INSTANCE_IDS[i]}

    NEW_ID=${NEW_INSTANCE_IDS[i]}
 
    if [[ -n "$OLD_ID" && -n "$NEW_ID" ]]; then

        echo "Replacing Instance ID: $OLD_ID → $NEW_ID"

        sed -i "s/$OLD_ID/$NEW_ID/g" dashboardTest.json

    fi

done
 
# Replace only the last 2 private DNS names correctly

for ((i=0; i<2; i++)); do

    OLD_DNS=${CURRENT_PRIVATE_DNS[i]}

    NEW_DNS=${NEW_PRIVATE_DNS[i]}
 
    if [[ -n "$OLD_DNS" && -n "$NEW_DNS" ]]; then

        echo "Replacing Private DNS: $OLD_DNS → $NEW_DNS"

        sed -i "s/$OLD_DNS/$NEW_DNS/g" dashboardTest.json

    fi

done
 

aws cloudwatch put-dashboard --dashboard-name "$DASHBOARD_NAME" --dashboard-body file://dashboardTest.json

rm -f dashboardTest.json aws-instances.txt
echo "CloudWatch dashboard updated successfully."


