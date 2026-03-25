#!/usr/bin/bash

#set -euo pipefail

notify() {

  cat << EOF >> outMSG_$$


Hi,

DDE scheduled autoscaling (down-scaling) was triggered. Full log attached.

Kind regards
DDE Operations support

EOF

  tac $LOG_FILE | awk '/={3,}/ && !s { s=1; print; next } { print } /={3,}/ && s { exit } ' | tac > tac_$$
  mutt -s "DDE Scheduled Autoscaling (down-scaling) invoked" "arnulf.hanauer@vcontractor.co.za,arnulf.hanauer@condorgreen.com" -a tac_$$ < outMSG_$$
  sleep 5
  rm outMSG_$$ tac_$$

}

export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/ec2-user:/home/ec2-user:/home/ec2-user/.local/bin:/home/ec2-user/bin

REGION="af-south-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/fixed-aurora-autoscale.log"

BASE_CLASS="db.r5.xlarge"
SCALE_CLASS="db.r5.4xlarge"

exec >> >(tee -a "$LOG_FILE") 2>&1
echo "[$(TZ=Africa/Johannesburg date '+%F %T %Z')] START aurora-downsize"

export AWS_DEFAULT_REGION="$REGION"

CLUSTER_ID="prd-dde"
if [[ -z "$CLUSTER_ID" ]]; then
	CLUSTER_ID=$(aws rds describe-db-clusters --query 'DBClusters[?Status==`available`][0].DBClusterIdentifier' --output text)
fi

if [[ -z "$CLUSTER_ID" || "$CLUSTER_ID" == "None" ]]; then
  echo "No available cluster found, exiting."
  echo "=================================================="
  notify
  exit 1
fi

WRITER_ID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)

READER_ID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' --output text)

echo "Cluster=$CLUSTER_ID Writer=$WRITER_ID Reader=$READER_ID"

if [[ -z "$READER_ID" || "$READER_ID" == "None" ]]; then
  echo "No reader instance found; cannot downsize pattern (need writer+reader)."
  echo "=============================================================================================="
  #tac $LOG_FILE | awk '/={3,}/ && !s { s=1; print; next } { print } /={3,}/ && s { exit } ' | tac | awk '{print $0}' | mutt -s "DDE Scheduled Autoscaling invoked" "arnulf.hanauer@vcontractor.co.za,arnulf.hanauer@condorgreen.com"
  notify
  exit 1
fi

WRITER_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$WRITER_ID" --query 'DBInstances[0].DBInstanceClass' --output text)
READER_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$READER_ID" --query 'DBInstances[0].DBInstanceClass' --output text)

echo "Writer class: $WRITER_CLASS, Reader class: $READER_CLASS"

if [[ "$WRITER_CLASS" != "$SCALE_CLASS" || "$READER_CLASS" != "$BASE_CLASS" ]]; then
  echo "Cluster not in expected layout (Writer=$SCALE_CLASS, Reader=$BASE_CLASS). Aborting downsize."
  echo "=============================================================================================="
  notify
  #tac $LOG_FILE | awk '/={3,}/ && !s { s=1; print; next } { print } /={3,}/ && s { exit } ' | tac | awk '{printf( $0)}' | mutt -s "DDE Scheduled Autoscaling invoked" "arnulf.hanauer@vcontractor.co.za,arnulf.hanauer@condorgreen.com"
  exit 1
fi

# Step 1: Fail over to the small instance (the reader)
echo "Failing over cluster $CLUSTER_ID to small instance $READER_ID (will become writer)."
aws rds failover-db-cluster --db-cluster-identifier "$CLUSTER_ID" --target-db-instance-identifier "$READER_ID"

echo "Sleeping between failover to allow state update"
sleep 15

echo "Waiting for cluster to be available after failover..."
aws rds wait db-cluster-available --db-cluster-identifier "$CLUSTER_ID"

# After failover, the previous writer is now reader – scale it down
NEW_READER_ID="$WRITER_ID"

#NEW_READER_ID="prd-dde-reader"
NEW_READER_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$NEW_READER_ID" --query 'DBInstances[0].DBInstanceClass' --output text)

echo "New reader (old writer) is $NEW_READER_ID class $NEW_READER_CLASS"

if [[ "$NEW_READER_CLASS" == "$BASE_CLASS" ]]; then
  echo "New reader already at base class $BASE_CLASS; nothing to do."
else
  echo "Modifying new reader $NEW_READER_ID from $NEW_READER_CLASS to $BASE_CLASS (ApplyImmediately=true)."
  aws rds modify-db-instance --db-instance-identifier "$NEW_READER_ID" --db-instance-class "$BASE_CLASS" --apply-immediately

  sleep 15

  date
  echo "Waiting for instance $NEW_READER_ID to become available..."
  aws rds wait db-instance-available --db-instance-identifier "$NEW_READER_ID"
  date
  echo "End wait"
fi

echo "Downsize complete. Cluster should now have writer=$READER_ID (small), reader=$NEW_READER_ID (small)."
echo "[$(TZ=Africa/Johannesburg date '+%F %T %Z')] END aurora-downsize"
echo
echo "========================================== downsize ends ==================================================================="
echo

#tac $LOG_FILE | awk '/={3,}/ && !s { s=1; print; next } { print } /={3,}/ && s { exit } ' | tac | awk '{print $0}' | mutt -s "DDE Scheduled Autoscaling invoked" "arnulf.hanauer@vcontractor.co.za,arnulf.hanauer@condorgreen.com"
notify
