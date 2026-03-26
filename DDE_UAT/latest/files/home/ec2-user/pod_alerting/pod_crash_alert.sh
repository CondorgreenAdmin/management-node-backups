#!/bin/bash

# PURPOSE:
#   Check cluster for unhealthy/crashed pods and send an email alert when problem pod is found.

# ALERT IS TRIGGERED FOR: CrashLoopBackOff, Error, ImagePullBackOff, ErrImagePull, Failed, Evicted

# NOTES:
#   - This script is for one management node / one environment.
#   - This first version is for DDE UAT.
#   - It assumes kubectl is already working from this management node.
#   - It uses sendmail directly because that is working on the node.

# BASIC CONFIGURATION: Edit these values for each environment
# -----------------------------------------------------------

# Environment 
ENV_NAME="DDE_UAT"

# Cluster name used in the email subject/body
CLUSTER_NAME="dev-dde-eks-cluster-3"

# List of email recipients
# Separate addresses with spaces
RECIPIENTS=(
  "crystal.jaftha@condorgreen.com"
  # "person2@company.com"
  # "person3@company.com"
)

# Local working directory for temp files and logs
WORK_DIR="/home/ec2-user/pod_alerting"

# Temporary working files
PODS_FILE="$WORK_DIR/pods_output.txt"
PROBLEM_FILE="$WORK_DIR/problem_pods.txt"
EMAIL_FILE="$WORK_DIR/email_body.txt"

# Number of log lines to include in the email
LOG_LINES=50

# Path to sendmail
SENDMAIL_BIN="/usr/sbin/sendmail"

# PREP WORK
# ----------
# Create work directory if it does not already exist
mkdir -p "$WORK_DIR"

# Clear temporary files at the start of each run
> "$PODS_FILE"
> "$PROBLEM_FILE"
> "$EMAIL_FILE"

# HELPER FUNCTION: WRITE LOG MESSAGE
# -----------------------------------
log_message() {
  # Print timestamped messages so script output is easier to read in cron logs
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# HELPER FUNCTION: SEND EMAIL
# ---------------------------
send_email() {
  local subject="$1"
  local body_file="$2"

  # Build comma-separated recipient list for the email header
  local to_header
  to_header=$(IFS=, ; echo "${RECIPIENTS[*]}")

  {
    echo "To: $to_header"
    echo "Subject: $subject"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo
    cat "$body_file"
  } | "$SENDMAIL_BIN" -t
}

# STEP 1: GET ALL PODS FROM ALL NAMESPACES
# -----------------------------------------
log_message "Fetching pod information..."

kubectl get pods -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,REASON:.status.containerStatuses[*].state.waiting.reason' \
  --no-headers > "$PODS_FILE" 2>/dev/null

if [ $? -ne 0 ]; then
  log_message "ERROR: Failed to get pod information."

  {
    echo "Environment: $ENV_NAME"
    echo "Cluster: $CLUSTER_NAME"
    echo
    echo "The script failed while running:"
    echo "kubectl get pods -A"
    echo
    echo "Time: $(date)"
  } > "$EMAIL_FILE"

  send_email "[$ENV_NAME] ERROR - failed to fetch pod data" "$EMAIL_FILE"
  exit 1
fi

# STEP 2: FIND PROBLEM PODS
# --------------------------
log_message "Checking for crashed/problem pods..."

awk '
{
  phase=$3
  reason=""
  if (NF > 3) {
    for (i=4; i<=NF; i++) {
      reason = reason $i " "
    }
  }
  if (phase == "Failed" || phase == "Error" || reason ~ /CrashLoopBackOff/ || reason ~ /ImagePullBackOff/ || reason ~ /ErrImagePull/ || reason ~ /Error/ || reason ~ /Evicted/) {
    print $0
  }
}
' "$PODS_FILE" > "$PROBLEM_FILE"

# STEP 4: EXIT CLEANLY IF NO PROBLEM PODS FOUND
# ----------------------------------------------
if [ ! -s "$PROBLEM_FILE" ]; then
  log_message "No crashed/problem pods found."
  exit 0
fi

log_message "Problem pods found. Sending alerts..."

# STEP 5: PROCESS EACH PROBLEM POD
# -----------------------------------

# For each problem pod:
#   - collect pod details
#   - collect logs
#   - send an email

# Email sent every time the script finds the problem.

while read -r line
do
  # Skip empty lines
  [ -z "$line" ] && continue

  # First 3 columns are easy to extract
  namespace=$(echo "$line" | awk '{print $1}')
  pod_name=$(echo "$line" | awk '{print $2}')
  phase=$(echo "$line" | awk '{print $3}')

  # Everything from column 4 onward is treated as the reason
  reason=$(echo "$line" | cut -d' ' -f4- | sed 's/^ *//')

  # If reason is blank, fall back to the phase value
  if [ -z "$reason" ]; then
    reason="$phase"
  fi

  log_message "Problem found: ${namespace}|${pod_name}|${reason}"

  # ----------------------------------------------------------------------------------------
  # Get pod description
  # ----------------------------------------------------------------------------------------
  describe_output=$(kubectl describe pod "$pod_name" -n "$namespace" 2>&1)

  # ----------------------------------------------------------------------------------------
  # Get current logs
  # This may fail for some pods, which is okay - we include the error text in the email
  # ----------------------------------------------------------------------------------------
  current_logs=$(kubectl logs "$pod_name" -n "$namespace" --tail="$LOG_LINES" 2>&1)

  # ----------------------------------------------------------------------------------------
  # Get previous logs
  # This is useful for restarted containers such as CrashLoopBackOff pods
  # ----------------------------------------------------------------------------------------
  previous_logs=$(kubectl logs "$pod_name" -n "$namespace" --previous --tail="$LOG_LINES" 2>&1)

  # ----------------------------------------------------------------------------------------
  # Build the email body
  # ----------------------------------------------------------------------------------------
  {
    echo "Pod Crash / Problem Alert"
    echo "============================================================"
    echo "Environment : $ENV_NAME"
    echo "Cluster     : $CLUSTER_NAME"
    echo "Namespace   : $namespace"
    echo "Pod Name    : $pod_name"
    echo "Phase       : $phase"
    echo "Reason      : $reason"
    echo "Time        : $(date)"
    echo
    echo "Original pod line"
    echo "------------------------------------------------------------"
    echo "$line"
    echo
    echo "kubectl describe pod"
    echo "------------------------------------------------------------"
    echo "$describe_output"
    echo
    echo "Current logs (last $LOG_LINES lines)"
    echo "------------------------------------------------------------"
    echo "$current_logs"
    echo
    echo "Previous logs (last $LOG_LINES lines)"
    echo "------------------------------------------------------------"
    echo "$previous_logs"
    echo
    echo "End of report"
  } > "$EMAIL_FILE"
  
  # Send email
  # ----------------------------------------------------------------------------------------
  send_email "[$ENV_NAME] Pod Alert - $namespace / $pod_name / $reason" "$EMAIL_FILE"

  if [ $? -eq 0 ]; then
    log_message "Email sent for: ${namespace}|${pod_name}|${reason}"
  else
    log_message "ERROR: Failed to send email for: ${namespace}|${pod_name}|${reason}"
  fi

done < "$PROBLEM_FILE"

# Complete
log_message "Script completed."
exit 0
