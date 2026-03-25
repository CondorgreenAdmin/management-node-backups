#!/usr/bin/bash

#set -euo pipefail

notify() {
  #tac $LOG_FILE | awk '/={3,}/ && !s { s=1; print; next } { print } /={3,}/ && s { exit } ' | tac  > tac_$$
  #mutt -s "DDE Scheduled Autoscaling invoked" "arnulf.hanauer@vcontractor.co.za,arnulf.hanauer@condorgreen.com" < tac_$$
  tac $LOG_FILE | awk '/={3,}/ && !s { s=1; print; next } { print } /={3,}/ && s { exit } ' | tac | mutt -s "DDE Scheduled Autoscaling invoked" "arnulf.hanauer@vcontractor.co.za,arnulf.hanauer@condorgreen.com" 
  #rm tac_$$
}

export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

REGION="af-south-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/ttt.log"

BASE_CLASS="db.r5.xlarge"
SCALE_CLASS="db.r5.4xlarge"

exec >> >(tee -a "$LOG_FILE") 2>&1

echo "AWS PATH: $PATH"
which aws || true
type -a aws || true
aws --version || true


echo "[$(TZ=Africa/Johannesburg date '+%F %T %Z')] START aurora-upsize"

export AWS_DEFAULT_REGION="$REGION"

CLUSTER_ID="prd-dde"

WRITER_ID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)

READER_ID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' --output text)

echo "Cluster=$CLUSTER_ID Writer=$WRITER_ID Reader=$READER_ID"

READER_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$READER_ID" --query 'DBInstances[0].DBInstanceClass' --output text)

echo "Current reader class: $READER_CLASS"

date

echo "Waiting for cluster to be available after failover..."
aws rds wait db-cluster-available --db-cluster-identifier "$CLUSTER_ID"

NEW_WRITER=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)

echo "Upsize complete. New writer: $NEW_WRITER (expected $READER_ID)."
echo "[$(TZ=Africa/Johannesburg date '+%F %T %Z')] END aurora-upsize"
echo
echo "============================================= upsize ends ============================================================================"
echo

#notify
