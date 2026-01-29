#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Condorgreen Management Node Backup -> S3 (NO GIT)
#
# Backs up:
#   - All *.sh scripts
#   - Selected config files (by extension list)
#   - FULL crons (user crontab + system cron locations if readable)
#
# Uploads to S3 in a structure that mirrors the Git version:
#
#   s3://<BUCKET>/<BASE_PREFIX>/<ENV_NAME>/
#       latest/
#         files/<full/path/...>
#         crons/<...>
#         .manifest.sha256
#       YYYY-MM-DD/
#         files/<only changed files...>
#         crons/<only changed...>
#
# Key rules:
#   - Dated folders never overwrite each other (each date has its own folder).
#   - Dated folders contain ONLY changed files (no duplicates).
#   - latest/ is a protected snapshot (never deleted).
#   - Retention deletes dated folders older than ~3 months (93 days).
#
# Note:
#   - If a file is deleted on the node, it may remain in latest/ (often desirable).
#   - This script is intentionally written so adding Git output later is easy:
#       * same "stage latest" and "stage date" folders
#       * same manifest approach
################################################################################
########################################
# 0) LOAD CONDORGREEN AWS CREDS (FROM FILE NEXT TO SCRIPT)
########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/s3_backup.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Credentials file not found: $ENV_FILE" >&2
  echo "Create it next to the script with AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_DEFAULT_REGION" >&2
  exit 1
fi
# Export variables from the env file for this script process only
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

########################################
# 1) REQUIRED CONFIGURATION (EDIT THESE)
########################################

# >>> SET THIS PER NODE <<<
ENV_NAME="DDE_UAT"

# S3 target
S3_BUCKET="management-node-backups"            

# Optional: if your AWS CLI needs a profile, set it here (leave empty for instance role/default creds)
AWS_PROFILE=""                               # e.g. "pfp-prod" or "" for default

########################################
# 2) FIXED SETTINGS (KEEP SIMPLE)
########################################

# Retention ~ 3 months (approx). Keeps script simple and predictable.
RETENTION_DAYS=93

# Local working folder (temporary staging + logs)
WORKDIR="/var/tmp/mgmt-node-backup-s3"
LOG_DIR="$HOME/backups/s3_backups/logs"
LOG_FILE="$LOG_DIR/s3_backup.log"

# Where to search. Avoid scanning "/" to keep it fast and low-noise.
SEARCH_ROOTS=(
  "/home"
  "/opt"
  "/usr/local/bin"
  "/etc"
)

# What counts as config files (tweak if needed)
CONFIG_EXTS=(
  "conf" "cfg" "cnf" "ini" "properties" "yaml" "yml" "json" "toml" "env"
)

# Exclusions (skip system pseudo dirs and high-noise paths)
EXCLUDE_PATHS=(
  "/proc" "/sys" "/dev" "/run" "/var/lib" "/var/cache" "/var/tmp" "$WORKDIR"
)

# Allowed envs (Arnie’s required base folders)
ALLOWED_ENVS=(
  "DDE_UAT" "DDE_PROD"
  "PFP_UAT" "PFP_PROD"
  "BM_NONPROD" "BM_PREPROD" "BM_PROD"
)

########################################
# 3) BASIC VALIDATION
########################################

env_ok="false"
for e in "${ALLOWED_ENVS[@]}"; do
  if [[ "$ENV_NAME" == "$e" ]]; then env_ok="true"; break; fi
done
if [[ "$env_ok" != "true" ]]; then
  echo "ERROR: ENV_NAME='$ENV_NAME' not allowed. Allowed: ${ALLOWED_ENVS[*]}" >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI is not installed on this node." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================================================"
echo "START: $(date -Is)"
echo "ENV_NAME=$ENV_NAME"
echo "S3_BUCKET=$S3_BUCKET"
echo "RETENTION_DAYS=$RETENTION_DAYS"
echo "================================================================================"

########################################
# 4) AWS CLI WRAPPER (keeps commands clean)
########################################

AWS_CMD=(aws)
if [[ -n "$AWS_PROFILE" ]]; then
  AWS_CMD+=(--profile "$AWS_PROFILE")
fi

########################################
# 5) PATH HELPERS
########################################

is_excluded_path() {
  local p="$1"
  for ex in "${EXCLUDE_PATHS[@]}"; do
    if [[ "$p" == "$ex"* ]]; then
      return 0
    fi
  done
  return 1
}

# Store full path context under files/<abs-path-without-leading-slash>
relpath_from_abs() {
  local abs="$1"
  abs="${abs#/}"
  echo "files/$abs"
}

file_hash() {
  local f="$1"
  sha256sum "$f" | awk '{print $1}'
}

# S3 “root” prefix for this env
# Final structure: s3://bucket/baseprefix/ENV_NAME/...
S3_ENV_PREFIX="${ENV_NAME}/"
S3_LATEST_PREFIX="${S3_ENV_PREFIX}latest/"
S3_DATE_PREFIX="${S3_ENV_PREFIX}$(date +%F)/"

# Where we store the manifest in S3 (under latest/)
S3_MANIFEST_KEY="${S3_LATEST_PREFIX}.manifest.sha256"

########################################
# 6) PREPARE LOCAL WORKDIR
########################################

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Temporary files/dirs
TMP_LIST="$(mktemp)"
CRON_TMP_DIR="$(mktemp -d)"
STAGE_LATEST="$(mktemp -d)"
STAGE_DATE="$(mktemp -d)"
NEW_MANIFEST="$(mktemp)"
OLD_MANIFEST="$(mktemp)"

cleanup() {
  rm -f "$TMP_LIST" "$NEW_MANIFEST" "$OLD_MANIFEST" || true
  rm -rf "$CRON_TMP_DIR" "$STAGE_LATEST" "$STAGE_DATE" || true
}
trap cleanup EXIT

########################################
# 7) COLLECT SCRIPTS + CONFIG FILES
########################################

echo "Collecting candidate files (scripts + configs)..."

for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  is_excluded_path "$root" && continue

  # shell scripts
  find "$root" -type f -name "*.sh" 2>/dev/null >> "$TMP_LIST" || true

  # configs by extension
  for ext in "${CONFIG_EXTS[@]}"; do
    find "$root" -type f -iname "*.${ext}" 2>/dev/null >> "$TMP_LIST" || true
  done
done

sort -u "$TMP_LIST" -o "$TMP_LIST"
echo "Found $(wc -l < "$TMP_LIST" | tr -d ' ') candidate files."

########################################
# 8) COLLECT FULL CRONS
########################################

echo "Collecting FULL crons..."

collect_crons_to_dir() {
  local outdir="$1"
  mkdir -p "$outdir"

  # Current user's crontab
  if crontab -l >/dev/null 2>&1; then
    crontab -l > "$outdir/user_crontab.txt"
  else
    echo "# No user crontab for $(whoami) on $(hostname) at $(date -Is)" > "$outdir/user_crontab.txt"
  fi

  # System crontab
  if [[ -r /etc/crontab ]]; then
    cp -f /etc/crontab "$outdir/etc_crontab"
  else
    echo "# /etc/crontab not readable on $(hostname) at $(date -Is)" > "$outdir/etc_crontab"
  fi

  # /etc/cron.d
  if [[ -d /etc/cron.d ]]; then
    mkdir -p "$outdir/etc_cron_d"
    while IFS= read -r -d '' f; do
      [[ -r "$f" ]] || continue
      cp -f "$f" "$outdir/etc_cron_d/$(basename "$f")" || true
    done < <(find /etc/cron.d -maxdepth 1 -type f -print0 2>/dev/null)
  fi

  # cron.hourly/daily/weekly/monthly
  for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    if [[ -d "$d" ]]; then
      sub="$(basename "$d")"
      mkdir -p "$outdir/$sub"
      while IFS= read -r -d '' f; do
        [[ -r "$f" ]] || continue
        cp -f "$f" "$outdir/$sub/$(basename "$f")" || true
      done < <(find "$d" -maxdepth 1 -type f -print0 2>/dev/null)
    fi
  done
}

collect_crons_to_dir "$CRON_TMP_DIR"

########################################
# 9) DOWNLOAD PREVIOUS MANIFEST (FROM S3)
########################################

echo "Downloading previous manifest from S3 (if exists)..."

# Try to download; if missing, we just treat it as first run.
if "${AWS_CMD[@]}" s3 cp "s3://${S3_BUCKET}/${S3_MANIFEST_KEY}" "$OLD_MANIFEST" >/dev/null 2>&1; then
  echo "Previous manifest found."
else
  echo "No previous manifest (first run or none uploaded yet)."
  : > "$OLD_MANIFEST"
fi

declare -A prev_hash
while read -r h p; do
  [[ -n "$h" && -n "$p" ]] || continue
  prev_hash["$p"]="$h"
done < "$OLD_MANIFEST"

########################################
# 10) CHANGE DETECTION + STAGING
########################################

changed_count=0

track_file() {
  local src="$1"
  local rel="$2"

  [[ -r "$src" ]] || return 0

  local h
  h="$(file_hash "$src")"

  # Always record current state into the new manifest
  echo "$h  $rel" >> "$NEW_MANIFEST"

  # Compare against previous
  local prev="${prev_hash[$rel]:-}"
  if [[ "$h" != "$prev" ]]; then
    changed_count=$((changed_count + 1))

    # Stage into latest overlay
    mkdir -p "$STAGE_LATEST/$(dirname "$rel")"
    cp -f "$src" "$STAGE_LATEST/$rel"

    # Stage into dated folder (only changed)
    mkdir -p "$STAGE_DATE/$(dirname "$rel")"
    cp -f "$src" "$STAGE_DATE/$rel"
  fi
}

echo "Detecting changes for scripts/configs..."
while IFS= read -r abs; do
  [[ -n "$abs" ]] || continue
  is_excluded_path "$abs" && continue
  track_file "$abs" "$(relpath_from_abs "$abs")"
done < "$TMP_LIST"

echo "Detecting changes for crons..."
while IFS= read -r -d '' f; do
  # Store under crons/<relative path inside cron tmp dir>
  rel="crons/${f#$CRON_TMP_DIR/}"
  track_file "$f" "$rel"
done < <(find "$CRON_TMP_DIR" -type f -print0 2>/dev/null)

sort -u "$NEW_MANIFEST" -o "$NEW_MANIFEST"

if [[ "$changed_count" -eq 0 ]]; then
  echo "No changes detected. Nothing to upload."
  exit 0
fi

echo "Changes detected: $changed_count changed files."

########################################
# 11) UPLOAD CHANGES TO S3 (LATEST + DATED)
########################################

echo "Uploading changed files to S3 latest/ ..."
# Upload only the changed overlay for latest/
# (latest/ retains older files that did not change)
"${AWS_CMD[@]}" s3 sync "$STAGE_LATEST/" "s3://${S3_BUCKET}/${S3_LATEST_PREFIX}" --only-show-errors

echo "Uploading changed files to S3 dated folder: ${S3_DATE_PREFIX} ..."
"${AWS_CMD[@]}" s3 sync "$STAGE_DATE/" "s3://${S3_BUCKET}/${S3_DATE_PREFIX}" --only-show-errors

echo "Uploading updated manifest to S3 latest/ ..."
"${AWS_CMD[@]}" s3 cp "$NEW_MANIFEST" "s3://${S3_BUCKET}/${S3_MANIFEST_KEY}" --only-show-errors

########################################
# 12) RETENTION: DELETE OLD DATED FOLDERS ONLY
########################################

echo "Applying retention (delete dated folders older than ${RETENTION_DAYS} days)..."

# Compute cutoff date (YYYY-MM-DD). On Linux, date -d works.
CUTOFF_DATE="$(date -d "-${RETENTION_DAYS} days" +%F)"

# List “folders” (CommonPrefixes) immediately under the env prefix
# We will delete prefixes that match YYYY-MM-DD and are older than cutoff.
# NOTE: This is a simple, readable approach; not the most compact one-liner.
COMMON_PREFIXES_JSON="$("${AWS_CMD[@]}" s3api list-objects-v2 \
  --bucket "$S3_BUCKET" \
  --prefix "$S3_ENV_PREFIX" \
  --delimiter "/" \
  --query 'CommonPrefixes[].Prefix' \
  --output text 2>/dev/null || true)"

# If empty, nothing to delete
if [[ -z "${COMMON_PREFIXES_JSON:-}" ]]; then
  echo "No dated folders found to evaluate for retention."
  echo "DONE: $(date -Is)"
  exit 0
fi

# Iterate each prefix returned (space-separated)
for p in $COMMON_PREFIXES_JSON; do
  # p looks like: baseprefix/ENV_NAME/YYYY-MM-DD/  OR baseprefix/ENV_NAME/latest/
  base="$(basename "${p%/}")"  # strip trailing slash then basename
  if [[ "$base" == "latest" ]]; then
    continue
  fi

  # Match date folders only
  if [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    # Compare strings works for YYYY-MM-DD format
    if [[ "$base" < "$CUTOFF_DATE" ]]; then
      echo "Deleting old dated folder: s3://${S3_BUCKET}/${p}"
      "${AWS_CMD[@]}" s3 rm "s3://${S3_BUCKET}/${p}" --recursive --only-show-errors
    fi
  fi
done

echo "================================================================================"
echo "DONE: $(date -Is)"
echo "Uploaded changes: $changed_count"
echo "================================================================================"

################################################################################
# LOGROTATE NOTE
#
# This script logs to:
#   /var/log/mgmt-node-backups/s3_backup.log
#
# You should configure logrotate so this file does not grow forever.
################################################################################
