#!/usr/bin/env bash
#set -euo pipefail
cd ~/automation/restoreTests

# ====== CONFIG ======
AWS_REGION="af-south-1"
REPORT_PLAN_NAME="Automated_Restore_testing"

DOWNLOAD_DIR="./aws-backup-reports"
mkdir -p "$DOWNLOAD_DIR"

# Optional: consistent local filename (keeps the AWS object name too)
# If true, we'll save a second copy named like restore-jobs-YYYY-MM-DD.csv
SAVE_DATED_COPY="true"

# Optional email-out (requires mailx or similar installed/configured)
SEND_EMAIL="true"
#EMAIL_TO="DDE-Notifications@vodafone.onmicrosoft.com"
EMAIL_TO=$(</home/ec2-user/paths/EMAIL_ALERTS)
EMAIL_SUBJECT_PREFIX="[AWS Backup] Automated Restore Jobs Report"
# ====================

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

echo "[$(ts)] Starting AWS Backup report job for plan: ${REPORT_PLAN_NAME} (region: ${AWS_REGION})"

REPORT_JOB_ID=$(
  aws backup start-report-job \
    --region "$AWS_REGION" \
    --report-plan-name "$REPORT_PLAN_NAME" \
    --query 'ReportJobId' \
    --output text
)

echo "[$(ts)] Started report job: $REPORT_JOB_ID"

# Poll until complete
while true; do
  STATUS=$(
    aws backup describe-report-job \
      --region "$AWS_REGION" \
      --report-job-id "$REPORT_JOB_ID" \
      --query 'ReportJob.Status' \
      --output text
  )

  echo "[$(ts)] Status: $STATUS"

  if [[ "$STATUS" == "COMPLETED" ]]; then
    break
  elif [[ "$STATUS" == "FAILED" ]]; then
    echo "[$(ts)] Report job FAILED. Full details:"
    aws backup describe-report-job --region "$AWS_REGION" --report-job-id "$REPORT_JOB_ID" --output json
    exit 1
  fi

  sleep 15
done

# Get S3 destination (authoritative)
BUCKET=$(
  aws backup describe-report-job \
    --region "$AWS_REGION" \
    --report-job-id "$REPORT_JOB_ID" \
    --query 'ReportJob.ReportDestination.S3BucketName' \
    --output text
)

CSV_KEY=$(
  aws backup describe-report-job \
    --region "$AWS_REGION" \
    --report-job-id "$REPORT_JOB_ID" \
    --query "ReportJob.ReportDestination.S3Keys[?ends_with(@, '.csv')]|[0]" \
    --output text
)

if [[ -z "${CSV_KEY}" || "${CSV_KEY}" == "None" ]]; then
  echo "[$(ts)] Could not find CSV key in ReportDestination.S3Keys. Full details:"
  aws backup describe-report-job --region "$AWS_REGION" --report-job-id "$REPORT_JOB_ID" --output json
  exit 2
fi

AWS_FILENAME="$(basename "$CSV_KEY")"
DEST="$DOWNLOAD_DIR/$AWS_FILENAME"

echo "[$(ts)] Downloading s3://$BUCKET/$CSV_KEY -> $DEST"
aws s3 cp --region "$AWS_REGION" "s3://$BUCKET/$CSV_KEY" "$DEST"

echo "[$(ts)] Downloaded: $DEST"

# Optional: save a predictable dated filename too
if [[ "${SAVE_DATED_COPY}" == "true" ]]; then
  DAYSTAMP="$(date -u +%F)"
  DATED_DEST="$DOWNLOAD_DIR/restore-jobs-${DAYSTAMP}.csv"
  cp -f "$DEST" "$DATED_DEST"
  echo "[$(ts)] Also saved dated copy: $DATED_DEST"
fi

# Optional email step
if [[ "${SEND_EMAIL}" == "true" ]]; then
  DAYSTAMP_LOCAL="$(date +%F)"
  SUBJECT="${EMAIL_SUBJECT_PREFIX} ${DAYSTAMP_LOCAL}"
  ATTACH_PATH="${DATED_DEST:-$DEST}"

  echo "[$(ts)] Emailing report to: $EMAIL_TO"
  # mailx variants differ by distro. This form works on many:
  echo -e "The AWS Backup automated restore jobs report is attached. \n\nJobId: $REPORT_JOB_ID \n\n$DEST\n\n\nKind regards\nPlatform support" | mutt -s "$SUBJECT" -a "$ATTACH_PATH" -- "$EMAIL_TO" 
  #echo -e "The AWS Backup automated restore jobs report is attached. \n\nJobId: $REPORT_JOB_ID \n\n$DEST\n\n\nKind regards\nPlatform support" | mutt -s "$SUBJECT" -a "$ATTACH_PATH" -- "$EMAIL_TO" 
  #mutt -s "DDE(Production) DMS report" -a $OUT_CSV -- $DL < $$outMSG

  echo "[$(ts)] Email sent."
fi
