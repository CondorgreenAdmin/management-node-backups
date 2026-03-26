#!/bin/bash

REGION="af-south-1"

# Get all instance IDs in the region
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

for INSTANCE in $INSTANCE_IDS; do
    # Get the current IMDSv2 setting
    TOKENS=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE" \
        --query "Reservations[0].Instances[0].MetadataOptions.HttpTokens" \
        --output text)

    if [ "$TOKENS" != "required" ]; then
        echo "Enabling IMDSv2 for instance $INSTANCE..."
        aws ec2 modify-instance-metadata-options \
            --region "$REGION" \
            --instance-id "$INSTANCE" \
            --http-tokens required \
            --http-endpoint enabled
        echo "IMDSv2 enabled for $INSTANCE."
    else
        echo "Instance $INSTANCE already has IMDSv2 required."
    fi
done
