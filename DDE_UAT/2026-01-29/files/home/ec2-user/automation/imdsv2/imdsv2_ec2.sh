#!/bin/bash

REGION="af-south-1"

DL=$(</home/ec2-user/paths/EMAIL_CG_SUPPORT)
#DL="michaelalex.dirks@vcontractor.co.za"

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
        echo -e "Hi,\n\nIMDSv2 was set on EC2 nodes for DDE UAT. Please see below the node that was updated.\nNode: $INSTANCE\n\nKind regards,\nPlatform" | mutt -s "UAT DDE EC2 IMDSv2 node update" -- $DL

    else
        echo "Instance $INSTANCE already has IMDSv2 required."
    fi
done

