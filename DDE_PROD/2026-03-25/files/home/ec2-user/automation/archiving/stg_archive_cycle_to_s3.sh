#!/usr/bin/env bash
#set -euo pipefail

cd ~/automation/archiving

CNF="/home/ec2-user/automation/rotations/dde-prd-admin.cnf"
cat $CNF | egrep -v database > tmpCNF

export PATH=/usr/local/bin/$PATH

########################################
# CONFIG — EDIT THESE
########################################
#HOST="your-mysql-host"
#PORT="3306"
#USER="your-user"
DB="DDE-prd"
#PASS_OPTS=""   # prefer ~/.my.cnf; otherwise e.g. -p'...' (not recommended)

ENV_NAME="prod"

S3_ROOT="s3://prd-dde-archives/mysql/staging_tables"   # base prefix only
S3_STORAGE_CLASS="GLACIER_IR"
S3_SSE="AES256"

EMAIL_TO="arnulf.hanauer@vcontractor.co.za,yusuf.pinn@vcontractor.co.za,blaine.simpson@vcontractor.co.za"
EMAIL_FROM="ec2user@vodacom.co.za"
EMAIL_SUBJECT_PREFIX="[DDE STG (Staging Tables) Cycle Archive]"

#PREFIXES=("dl_stg_epx" "dl_stg_sie")

DELETE_BATCH=50000
SLEEP_BETWEEN_BATCHES=1.2
GZIP_LEVEL=1

WORKDIR="./archive_run"
DRY_RUN=0  # 1 = reports only (no dump/upload/delete)
SKIP_DELETE=0   #full run without delete

########################################
# INPUT: which cycle to archive?
########################################
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <cycle_id_yyyymm>  (example: $0 202401)"
  exit 1
fi
CYCLE_ID="$1"

if ! [[ "$CYCLE_ID" =~ ^[0-9]{6}$ ]]; then
  echo "cycle_id must be 6 digits YYYYMM (e.g. 202401). Got: $CYCLE_ID"
  exit 1
fi

########################################
# HELPERS
########################################
mysql_cmd() {
  #mysql -h "$HOST" -P "$PORT" -u "$USER" $PASS_OPTS --protocol=tcp \
  #  --default-character-set=utf8mb4 "$@"
  mysql --defaults-extra-file=$CNF --defaults-group-suffix=1 "$@"
}

mysqldump_cmd() {
  #mysqldump -h "$HOST" -P "$PORT" -u "$USER" $PASS_OPTS --protocol=tcp "$@"
  mysqldump --defaults-extra-file=tmpCNF --defaults-group-suffix=1 "$@"
}

now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Parse bucket + key from s3://bucket/key...
s3_bucket_from_uri() { echo "$1" | sed -E 's#^s3://([^/]+)/.*#\1#'; }
s3_key_from_uri() { echo "$1" | sed -E 's#^s3://[^/]+/(.*)#\1#'; }


# Guardrail: confirm object exists and matches local file metadata
confirm_s3_object_matches_local() {
  local local_file="$1"
  local s3_uri="$2"
  local local_bytes local_sha bucket key remote_bytes

  local_bytes="$(wc -c < "$local_file" | tr -d ' ')"
  local_sha="$(sha256sum "$local_file" | awk '{print $1}')"

  bucket="$(s3_bucket_from_uri "$s3_uri")"
  key="$(s3_key_from_uri "$s3_uri")"

  # Confirm object exists and get size.
  # (Uses aws s3api head-object; very reliable.)
  remote_bytes="$(aws s3api head-object --bucket "$bucket" --key "$key" --query ContentLength --output text 2>/dev/null || true)"
  if [[ -z "$remote_bytes" || "$remote_bytes" == "None" ]]; then
    echo "S3 GUARD FAIL: object not found: $s3_uri"
    return 1
  fi

  if [[ "$remote_bytes" != "$local_bytes" ]]; then
    echo "S3 GUARD FAIL: size mismatch for $s3_uri (local=$local_bytes, s3=$remote_bytes)"
    return 1
  fi

  # Write sha256 to S3 object metadata for auditability (one-time per upload).
  # If you don't want this, comment out the next line.
  # Note: metadata can only be set on upload; we set it during aws s3 cp below via --metadata.
  # Here we just log what we expect.
  echo "S3 GUARD OK: $s3_uri exists and size matches; expected sha256=$local_sha"
  return 0
}

mkdir -p "$WORKDIR"
RUN_TS="$(date -u +"%Y%m%dT%H%M%SZ")"
RUN_ID="${ENV_NAME}_${DB}_cycle_${CYCLE_ID}_${RUN_TS}"
RUN_DIR="${WORKDIR}/${RUN_ID}"
mkdir -p "$RUN_DIR"

PRE_REPORT="${RUN_DIR}/precheck_${RUN_ID}.csv"
S3_REPORT="${RUN_DIR}/s3copy_${RUN_ID}.csv"
DEL_REPORT="${RUN_DIR}/deleted_${RUN_ID}.csv"
LOG_FILE="${RUN_DIR}/run_${RUN_ID}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "Run ID: $RUN_ID"
echo "Start: $(now_utc)"
echo "Archiving cycle_id = $CYCLE_ID"

########################################
# TABLE LIST
########################################
prefix_list=$(printf "'%s'," "${PREFIXES[@]}")
prefix_list="${prefix_list%,}"

TABLES="$(mysql_cmd -N -s "$DB" -e "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = DATABASE()
  	AND (LEFT(table_name, 10) IN ('dl_stg_epx', 'dl_stg_sie') OR TABLE_NAME LIKE 'dl_siebel_%sub_batched')
  ORDER BY table_name;
")"

if [[ -z "${TABLES// }" ]]; then
  echo "No tables matched prefixes; exiting."
  exit 1
fi

########################################
# 1) PRE-CHECK REPORT
########################################
echo "Generating pre-check report: $PRE_REPORT"
{
  echo "run_id,utc_ts,env,db,cycle_id,table_name,cycle_rows,total_rows,min_cycle_id,max_cycle_id"
  while read -r t; do
    [[ -z "$t" ]] && continue
    cycle_rows="$(mysql_cmd -N -s "$DB" -e "SELECT COUNT(*) FROM \`$t\` WHERE cycle_id = ${CYCLE_ID};")"
    total_rows="$(mysql_cmd -N -s "$DB" -e "SELECT COUNT(*) FROM \`$t\`;")"
    min_c="$(mysql_cmd -N -s "$DB" -e "SELECT MIN(cycle_id) FROM \`$t\`;")"
    max_c="$(mysql_cmd -N -s "$DB" -e "SELECT MAX(cycle_id) FROM \`$t\`;")"
    echo "${RUN_ID},$(now_utc),${ENV_NAME},${DB},${CYCLE_ID},${t},${cycle_rows},${total_rows},${min_c:-},${max_c:-}"
  done <<< "$TABLES"
} > "$PRE_REPORT"
echo "Pre-check completed."

########################################
# 2) ARCHIVE + COPY-TO-S3 REPORT
########################################
echo "Generating S3 copy report: $S3_REPORT"
{
  echo "run_id,utc_ts,env,db,cycle_id,table_name,cycle_rows,dump_file,bytes,sha256,s3_uri,upload_status"
} > "$S3_REPORT"

# We store per-table S3 URI + local dump path for later guarded deletes.
declare -A DUMP_FILE_BY_TABLE
declare -A S3_URI_BY_TABLE

if [[ "$DRY_RUN" -eq 1 || "$SKIP_DELETE" -eq 1 ]]; then
  echo "DRY_RUN=1: Skipping dump/upload/delete steps."
else
  while read -r t; do
    [[ -z "$t" ]] && continue

    cycle_rows="$(mysql_cmd -N -s "$DB" -e "SELECT COUNT(*) FROM \`$t\` WHERE cycle_id = ${CYCLE_ID};")"
    if [[ "$cycle_rows" -eq 0 ]]; then
      echo "[$t] No rows for cycle_id=${CYCLE_ID}; skipping dump/upload."
      echo "${RUN_ID},$(now_utc),${ENV_NAME},${DB},${CYCLE_ID},${t},0,,,,,SKIPPED_NO_ROWS" >> "$S3_REPORT"
      continue
    fi

    dump_file="${RUN_DIR}/${t}.cycle_id=${CYCLE_ID}.run=${RUN_TS}.sql.gz"
    s3_uri="${S3_ROOT}/${ENV_NAME}/${DB}/${t}/cycle_id=${CYCLE_ID}/run=${RUN_TS}/$(basename "$dump_file")"


    echo "[$t] Dumping ${cycle_rows} rows to $dump_file"
    mysqldump_cmd --single-transaction --quick --skip-lock-tables --set-gtid-purged=OFF --no-create-info --where="cycle_id=${CYCLE_ID}" "$DB" "$t" | gzip -"${GZIP_LEVEL}" > "$dump_file"

    bytes="$(wc -c < "$dump_file" | tr -d ' ')"
    sha256="$(sha256sum "$dump_file" | awk '{print $1}')"

    echo "[$t] Uploading to S3: $s3_uri"
    # Add sha256 as metadata to the S3 object for audit lookup later
    aws s3 cp "$dump_file" "$s3_uri" \
      --storage-class "$S3_STORAGE_CLASS" \
      --sse "$S3_SSE" \
      --metadata "sha256=${sha256},db=${DB},table=${t},cycle_id=${CYCLE_ID},run_ts=${RUN_TS}"

    echo "${RUN_ID},$(now_utc),${ENV_NAME},${DB},${CYCLE_ID},${t},${cycle_rows},$(basename "$dump_file"),${bytes},${sha256},${s3_uri},UPLOADED" \
      >> "$S3_REPORT"

    DUMP_FILE_BY_TABLE["$t"]="$dump_file"
    S3_URI_BY_TABLE["$t"]="$s3_uri"
  done <<< "$TABLES"
fi
echo "S3 copy report completed."

########################################
# 3) GUARDED DELETE + DELETED REPORT
########################################
echo "Generating deleted report: $DEL_REPORT"
{
  echo "run_id,utc_ts,env,db,cycle_id,table_name,rows_before,rows_deleted,rows_after,delete_status,guard_reason"
} > "$DEL_REPORT"


if [[ "$DRY_RUN" -eq 1 || "$SKIP_DELETE" -eq 1 ]]; then
  echo "DRY_RUN=1: Skipping delete step."
else
  while read -r t; do
    [[ -z "$t" ]] && continue

    before="$(mysql_cmd -N -s "$DB" -e "SELECT COUNT(*) FROM \`$t\` WHERE cycle_id = ${CYCLE_ID};")"
    if [[ "$before" -eq 0 ]]; then
      echo "[$t] No rows to delete for cycle_id=${CYCLE_ID}."
      echo "${RUN_ID},$(now_utc),${ENV_NAME},${DB},${CYCLE_ID},${t},0,0,0,SKIPPED_NO_ROWS," >> "$DEL_REPORT"
      continue
    fi

    dump_file="${DUMP_FILE_BY_TABLE[$t]:-}"
    s3_uri="${S3_URI_BY_TABLE[$t]:-}"

    # If we have rows but no dump/upload recorded, do NOT delete.
    if [[ -z "$dump_file" || -z "$s3_uri" ]]; then
      echo "[$t] GUARD FAIL: rows exist but no dump/upload recorded; not deleting."
      echo "${RUN_ID},$(now_utc),${ENV_NAME},${DB},${CYCLE_ID},${t},${before},0,${before},NOT_DELETED,NO_DUMP_OR_S3_URI" >> "$DEL_REPORT"
      continue
    fi

    # S3 guardrail: confirm object exists and size matches local file
    if ! confirm_s3_object_matches_local "$dump_file" "$s3_uri"; then
      echo "[$t] GUARD FAIL: S3 confirmation failed; not deleting."
      echo "${RUN_ID},$(now_utc),${ENV_NAME},${DB},${CYCLE_ID},${t},${before},0,${before},NOT_DELETED,S3_GUARD_FAILED" >> "$DEL_REPORT"
      continue
    fi

    echo "[$t] Guard OK. Deleting rows for cycle_id=${CYCLE_ID} in batches of ${DELETE_BATCH} (before=${before})"
    total_deleted=0

    while :; do
      deleted_this="$(mysql_cmd -N -s "$DB" -e "
        DELETE FROM \`$t\` WHERE cycle_id = ${CYCLE_ID} LIMIT ${DELETE_BATCH};
        SELECT ROW_COUNT();
      " | tail -n 1)"
      deleted_this="${deleted_this:-0}"
      total_deleted=$((total_deleted + deleted_this))

      echo "[$t] deleted batch=${deleted_this} total_deleted=${total_deleted}"
      [[ "$deleted_this" -lt "$DELETE_BATCH" ]] && break
      sleep "$SLEEP_BETWEEN_BATCHES"
    done

    after="$(mysql_cmd -N -s "$DB" -e "SELECT COUNT(*) FROM \`$t\` WHERE cycle_id = ${CYCLE_ID};")"
    status="DELETED_OK"
    reason=""
    if [[ "$after" -ne 0 ]]; then
      status="DELETED_PARTIAL"
      reason="ROWS_REMAIN_AFTER_DELETE"
    fi

    echo "${RUN_ID},$(now_utc),${ENV_NAME},${DB},${CYCLE_ID},${t},${before},${total_deleted},${after},${status},${reason}" >> "$DEL_REPORT"
  done <<< "$TABLES"
fi
echo "Deleted report completed."

########################################
# 4) EMAIL REPORTS
########################################
SUBJECT="${EMAIL_SUBJECT_PREFIX} ${ENV_NAME}/${DB} cycle=${CYCLE_ID} run=${RUN_TS}"
EMAIL_BODY="${RUN_DIR}/email_${RUN_ID}.txt"

{
  echo "MySQL cycle archive run: ${RUN_ID}"
  echo "UTC run timestamp: ${RUN_TS}"
  echo "Environment: ${ENV_NAME}"
  echo "Database: ${DB}"
  echo "Archived cycle_id: ${CYCLE_ID}"
  echo
  echo "S3 location pattern:"
  echo "  ${S3_ROOT}/${ENV_NAME}/${DB}/<table>/cycle_id=${CYCLE_ID}/run=${RUN_TS}/"
  echo
  echo "Guardrail:"
  echo "  Deletes only happen if the S3 object exists AND matches local dump size (sha256 stored as S3 metadata)."
  echo
  echo "Attachments:"
  echo "  - Pre-check report: $(basename "$PRE_REPORT")"
  echo "  - S3 copy report:   $(basename "$S3_REPORT")"
  echo "  - Deleted report:   $(basename "$DEL_REPORT")"
  echo "  - Full log:         $(basename "$LOG_FILE")"
} > "$EMAIL_BODY"

echo "Sending email to $EMAIL_TO"
mutt -e "set from=${EMAIL_FROM}" -s "$SUBJECT" -a "$PRE_REPORT" -a "$S3_REPORT" -a "$DEL_REPORT" -a "$LOG_FILE" -- "$EMAIL_TO" < "$EMAIL_BODY"

echo "Done: $(now_utc)"
echo "Run directory: $RUN_DIR"
