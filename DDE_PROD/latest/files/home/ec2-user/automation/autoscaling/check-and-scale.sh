#!/usr/bin/bash
#set -euo pipefail
REGION="af-south-1"

# === CONFIG – ADJUST FOR YOUR ENVIRONMENT =======================
# Your Aurora cluster identifier (from describe-db-clusters)
CLUSTER_ID="prd-dde"
# Your “small” and “big” classes
BASE_CLASS="db.r5.xlarge"
SCALE_CLASS="db.r5.2xlarge"
# Cooldowns (in minutes)
UPSCALE_COOLDOWN_MIN=15      # minimum time between scale-ups 15
DOWNSCALE_COOLDOWN_MIN=60    # minimum time we must stay scaled up before scaling down - 60
# Thresholds for scaling up
UPSCALE_CPU_THRESHOLD=80                  # 75
UPSCALE_DBLOAD_PER_VCPU_THRESHOLD=0.8   # DBLoad / vCPU 0.75
# Thresholds for scaling down (lower = hysteresis)
DOWNSCALE_CPU_THRESHOLD=40               # % 50
DOWNSCALE_DBLOAD_PER_VCPU_THRESHOLD=0.4  # DBLoad / vCPU 0.4
EVAL_POINTS=10                # how many 1-minute datapoints to evaluate

# =================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR"
LOG_FILE="$LOG_DIR/aurora-autoscale.log"
STATE_FILE="$LOG_DIR/aurora-autoscale.state"
UPSIZER="$SCRIPT_DIR/aurora-upsize.sh"
DOWNSIZER="$SCRIPT_DIR/aurora-downsize.sh"
mkdir -p "$LOG_DIR"

exec >> >(tee -a "$LOG_FILE") 2>&1
echo -n "[$(TZ=Africa/Johannesburg date '+%F %T %Z')] -> "
export AWS_DEFAULT_REGION="$REGION"

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    source "$STATE_FILE"
  else
    MODE="NORMAL"
    LAST_SCALE_UP=0
    LAST_SCALE_DOWN=0
  fi
}

save_state() {
  local tmp="${STATE_FILE}.tmp"
  {
    echo "MODE=$MODE"
    echo "LAST_SCALE_UP=$LAST_SCALE_UP"
    echo "LAST_SCALE_DOWN=$LAST_SCALE_DOWN"
  } > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

get_vcpus_for_class() {
  local class="$1"
  case "$class" in
    db.r5.large)  echo 2 ;;
    db.r5.xlarge) echo 4 ;;
    db.r5.2xlarge) echo 8 ;;
    # Fallback – adjust if you use other families
    *) echo 2 ;;
  esac
}

# Helper: minutes since timestamp (0 if ts=0)
mins_since() {
  local ts="$1"
  local now_epoch="$2"
  if [[ -z "$ts" || "$ts" -eq 0 ]]; then
    echo 999999
  else
    awk -v now="$now_epoch" -v t="$ts" 'BEGIN { printf "%.0f", (now-t)/60 }'
  fi
}

send_mail() {
   tail -20 "$LOG_DIR/aurora-autoscale.log" |  mutt -s "DDE Autoscaling invoked" "arnulf.hanauer@vcontractor.co.za,arnulf.hanauer@condorgreen.com"
}

# Time window for metrics (6 minutes to ensure 5 one-minute points)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START=$(date -u -d "11 minutes ago" +%Y-%m-%dT%H:%M:%SZ)

# === Resolve cluster and writer =================================
if [[ -z "$CLUSTER_ID" ]]; then
  CLUSTER_ID=$(aws rds describe-db-clusters \
    --query 'DBClusters[0].DBClusterIdentifier' --output text)
fi
if [[ -z "$CLUSTER_ID" || "$CLUSTER_ID" == "None" ]]; then
  echo "No DB cluster identifier resolved; check AWS credentials/region."
  exit 1
fi
CLUSTER_STATUS=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].Status' --output text)
if [[ "$CLUSTER_STATUS" != "available" ]]; then
  echo "Cluster $CLUSTER_ID status is '$CLUSTER_STATUS', not 'available'; skipping."
  exit 0
fi
WRITER_ID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" \
  --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)
WRITER_CLASS=$(aws rds describe-db-instances --db-instance-identifier "$WRITER_ID" \
  --query 'DBInstances[0].DBInstanceClass' --output text)
WRITER_VCPUS=$(get_vcpus_for_class "$WRITER_CLASS")
echo "Cluster=$CLUSTER_ID Writer=$WRITER_ID Class=$WRITER_CLASS vCPUs=$WRITER_VCPUS"

# === Pull CloudWatch metrics ====================================
METRICS_JSON=$(aws cloudwatch get-metric-data --start-time "$START" --end-time "$END" \
  --metric-data-queries '[
    {
      "Id":"cpu",
      "MetricStat":{
        "Metric":{
          "Namespace":"AWS/RDS",
          "MetricName":"CPUUtilization",
          "Dimensions":[{"Name":"DBInstanceIdentifier","Value":"'"$WRITER_ID"'"}]
        },
        "Period":60,
        "Stat":"Average"
      }
    },
    {
      "Id":"dbl",
      "MetricStat":{
        "Metric":{
          "Namespace":"AWS/RDS",
          "MetricName":"DBLoad",
          "Dimensions":[{"Name":"DBInstanceIdentifier","Value":"'"$WRITER_ID"'"}]
        },
        "Period":60,
        "Stat":"Average"
      }
    }
  ]' --output json)
# Optional: persist raw metrics snapshot to disk for debugging
echo "$METRICS_JSON" > "$LOG_DIR/aurora-metrics-last.json"
# Extract last N datapoints from .Values (CloudWatch returns newest → oldest)
# We just take the first EVAL_POINTS values.
readarray -t CPU_VALUES < <(
  echo "$METRICS_JSON" |
    jq -r '
      .MetricDataResults[]
      | select(.Id=="cpu")
      | .Values
      | .[0:10][]
    ' 2>/dev/null
)
readarray -t DBL_VALUES < <(
  echo "$METRICS_JSON" |
    jq -r '
      .MetricDataResults[]
      | select(.Id=="dbl")
      | .Values
      | .[0:10][]
    ' 2>/dev/null
)

#echo "DEBUG: CPU datapoints=${#CPU_VALUES[@]} DBLoad datapoints=${#DBL_VALUES[@]}"
if (( ${#CPU_VALUES[@]} < EVAL_POINTS || ${#DBL_VALUES[@]} < EVAL_POINTS )); then
  echo "Not enough datapoints yet (CPU=${#CPU_VALUES[@]} DBLoad=${#DBL_VALUES[@]}), skipping."
  exit 0
fi
#echo "Last $EVAL_POINTS samples (newest → older):"
all_up_ok=1
all_down_ok=1
for i in "${!CPU_VALUES[@]}"; do
  cpu="${CPU_VALUES[$i]:-0}"
  dbl="${DBL_VALUES[$i]:-0}"
  dbl_per_vcpu=$(awk -v d="$dbl" -v v="$WRITER_VCPUS" 'BEGIN { if (v>0) printf "%.1f", d/v; else printf "0.0" }')
  #printf "S%d: CPU=%.1f%% DBLoad=%.1f DBLoad/vCPU=%.1f  " \
  printf "CPU=%.1f%% DBLoad=%.1f DBLoad/vCPU=%.1f " \
    "$((i+1))" "$cpu" "$dbl" "$dbl_per_vcpu"
  # Upscale condition: all points must exceed thresholds (AND logic) - currently using OR logic, CPU more reactive than load
  awk -v c="$cpu" -v cth="$UPSCALE_CPU_THRESHOLD" \
      -v d="$dbl_per_vcpu" -v dth="$UPSCALE_DBLOAD_PER_VCPU_THRESHOLD" \
      'BEGIN { if (!(c>cth || d>dth)) exit 1 }' \
    || all_up_ok=0
  # Downscale condition: all points must be below thresholds
  awk -v c="$cpu" -v cth="$DOWNSCALE_CPU_THRESHOLD" \
      -v d="$dbl_per_vcpu" -v dth="$DOWNSCALE_DBLOAD_PER_VCPU_THRESHOLD" \
      'BEGIN { if (!(c<cth && d<dth)) exit 1 }' \
    || all_down_ok=0
done
echo

# === State & hysteresis =========================================
load_state
now_epoch=$(date +%s)
echo -n "State: MODE=${MODE:-UNKNOWN} LAST_SCALE_UP=${LAST_SCALE_UP:-0} LAST_SCALE_DOWN=${LAST_SCALE_DOWN:-0}  -:-  "
min_since_up=$(mins_since "${LAST_SCALE_UP:-0}" "$now_epoch")
min_since_down=$(mins_since "${LAST_SCALE_DOWN:-0}" "$now_epoch")
echo "Minutes since last scale up: $min_since_up, since last scale down: $min_since_down"
echo


case "${MODE:-NORMAL}" in
  NORMAL)
    if (( all_up_ok == 1 && min_since_up >= UPSCALE_COOLDOWN_MIN )); then
      echo "→ Conditions met for UPSCALE (NORMAL → HOT). Invoking $UPSIZER"
      if bash "$UPSIZER"; then
        MODE="HOT"
        LAST_SCALE_UP="$now_epoch"
        save_state
        echo "UPSCALE completed, state updated to MODE=HOT"
	send_mail
      else
        echo "UPSCALE script failed; state not changed."
      fi
    else
      #echo "In NORMAL mode – either thresholds not met or still in upscale cooldown."
      echo
    fi
    ;;
  HOT)
    if (( all_down_ok == 1 && min_since_up >= DOWNSCALE_COOLDOWN_MIN )); then
      echo "→ Conditions met for DOWNSCALE (HOT → NORMAL). Invoking $DOWNSIZER"
      if bash "$DOWNSIZER"; then
        MODE="NORMAL"
        LAST_SCALE_DOWN="$now_epoch"
        save_state
        echo "DOWNSCALE completed, state updated to MODE=NORMAL"
	send_mail
      else
        echo "DOWNSCALE script failed; state not changed."
      fi
    else
      #echo "In HOT mode – thresholds not low enough or still in downscale cooldown."
      echo
    fi
    ;;
  *)
    echo "Unknown mode '${MODE}', treating as NORMAL."
    MODE="NORMAL"
    save_state
    ;;
esac
