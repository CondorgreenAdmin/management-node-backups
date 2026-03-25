#!/usr/bin/bash

#set -euo pipefail

export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

REGION="af-south-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/test-aurora-autoscale.log"

BASE_CLASS="db.r5.xlarge"
SCALE_CLASS="db.r5.2xlarge"

exec >> >(tee -a "$LOG_FILE") 2>&1
echo "[$(TZ=Africa/Johannesburg date '+%F %T %Z')] START aurora-upsize"

export AWS_DEFAULT_REGION="$REGION"

CLUSTER_ID="prd-dde"
if [[ -z "$CLUSTER_ID" ]]; then
	CLUSTER_ID=$(aws rds describe-db-clusters --query 'DBClusters[?Status==`available`][0].DBClusterIdentifier' --output text)
fi	

if [[ -z "$CLUSTER_ID" || "$CLUSTER_ID" == "None" ]]; then
  echo "No available cluster found, exiting."
  exit 1
fi

WRITER_ID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)

READER_ID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' --output text)

echo "Cluster=$CLUSTER_ID Writer=$WRITER_ID Reader=$READER_ID"

if [[ -z "$READER_ID" || "$READER_ID" == "None" ]]; then
  echo "No reader instance found; cannot upsize pattern (need writer+reader)."
  exit 1
fi

READER_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$READER_ID" --query 'DBInstances[0].DBInstanceClass' --output text)

echo "Current reader class: $READER_CLASS"

if [[ "$READER_CLASS" == "$SCALE_CLASS" ]]; then
  echo "Reader already at $SCALE_CLASS; skipping modify."
else
  echo "Modifying reader $READER_ID from $READER_CLASS to $SCALE_CLASS (ApplyImmediately=true)."
  aws rds modify-db-instance --db-instance-identifier "$READER_ID" --db-instance-class "$SCALE_CLASS" --apply-immediately

  sleep 15

  date
  echo "Start instance polling"

  echo "Waiting for reader $READER_ID to become available..."
  aws rds wait db-instance-available --db-instance-identifier "$READER_ID"

  date
  echo "End instance polling"
fi



# Failover cluster to the (now big) reader
echo "Failing over cluster $CLUSTER_ID to new writer $READER_ID"
aws rds failover-db-cluster --db-cluster-identifier "$CLUSTER_ID" --target-db-instance-identifier "$READER_ID"

sleep 15
date

echo "Waiting for cluster to be available after failover..."
aws rds wait db-cluster-available --db-cluster-identifier "$CLUSTER_ID"

NEW_WRITER=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)

echo "Upsize complete. New writer: $NEW_WRITER (expected $READER_ID)."
echo "[$(TZ=Africa/Johannesburg date '+%F %T %Z')] END aurora-upsize"
