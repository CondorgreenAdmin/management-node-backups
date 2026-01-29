#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Management Node Backup -> GitHub (simple bash)
#
# Backs up (readable only):
#   - All *.sh scripts
#   - Config-like files by extension (conf/cfg/yaml/json/env/etc)
#   - Cron info (user crontab + system cron locations if readable)
#
# GitHub structure:
#   <repo>/
#     <ENV_NAME>/
#       latest/                (protected snapshot; never deleted)
#         files/<full/path/...>
#         crons/<...>
#         .manifest.sha256
#       YYYY-MM-DD[/]...       (dated snapshots; only CHANGED files)
#
# Key rules:
#   - Dated folders never overwrite each other
#   - Dated folders contain only changed files (no duplicates)
#   - latest/ is updated only for changed files (acts as a current snapshot)
#   - Retention deletes dated folders older than ~3 months
#
# Auth:
#   - Reads token from a file next to this script: github_backup.env
#   - The token variable name must be: BACKUP_STORE=github_pat_...
################################################################################

########################################
# 0) LOAD GITHUB TOKEN (FROM FILE NEXT TO SCRIPT)
########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="${SCRIPT_DIR}/github_backup.env"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "ERROR: Token file not found: $TOKEN_FILE" >&2
  echo "Create it with: BACKUP_STORE=github_pat_..." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$TOKEN_FILE"
set +a

if [[ -z "${BACKUP_STORE:-}" ]]; then
  echo "ERROR: BACKUP_STORE is not set in $TOKEN_FILE" >&2
  exit 1
fi

########################################
# 1) REQUIRED CONFIGURATION (EDIT THESE)
########################################
ENV_NAME="DDE_UAT"

GITHUB_ORG="CondorgreenAdmin"
GITHUB_REPO="management-node-backups"
GITHUB_BRANCH="main"

########################################
# 2) FIXED SETTINGS
########################################
RETENTION_DAYS=93

WORKDIR="/var/tmp/mgmt-node-backup-git"
REPO_DIR="${WORKDIR}/repo"

LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/github_backup.log"

SEARCH_ROOTS=(
  "/home"
  "/opt"
  "/usr/local/bin"
  "/etc"
)

CONFIG_EXTS=(
  "conf" "cfg" "cnf" "ini" "properties" "yaml" "yml" "json" "toml" "env"
)

EXCLUDE_PATHS=(
  "/proc" "/sys" "/dev" "/run" "/var/lib" "/var/cache" "/var/tmp" "$WORKDIR"
)

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
  [[ "$ENV_NAME" == "$e" ]] && env_ok="true" && break
done
if [[ "$env_ok" != "true" ]]; then
  echo "ERROR: ENV_NAME='$ENV_NAME' not allowed. Allowed: ${ALLOWED_ENVS[*]}" >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "ERROR: git not installed" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum not installed" >&2; exit 1; }

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================================================"
echo "START: $(date -Is)"
echo "ENV_NAME=$ENV_NAME"
echo "REPO=${GITHUB_ORG}/${GITHUB_REPO} branch=${GITHUB_BRANCH}"
echo "RETENTION_DAYS=$RETENTION_DAYS"
echo "================================================================================"

########################################
# 4) PREPARE REPO
########################################
mkdir -p "$WORKDIR"

# Don’t echo URL (it contains token)
GIT_URL="https://${BACKUP_STORE}@github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  rm -rf "$REPO_DIR"
  git clone --quiet "$GIT_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --all --prune --quiet
git checkout -B "$GITHUB_BRANCH" "origin/$GITHUB_BRANCH" --quiet
git pull --rebase --quiet

########################################
# 5) PATHS INSIDE REPO
########################################
ENV_DIR="${ENV_NAME}"
LATEST_DIR="${ENV_DIR}/latest"
MANIFEST="${LATEST_DIR}/.manifest.sha256"

mkdir -p "$LATEST_DIR"

# Dated folder name that never overwrites
DATE_STAMP="$(date +%F)"
DATE_DIR="${ENV_DIR}/${DATE_STAMP}"
if [[ -d "$DATE_DIR" ]]; then
  DATE_DIR="${ENV_DIR}/$(date +%F_%H%M%S)"
fi

########################################
# 6) HELPERS
########################################
is_excluded_path() {
  local p="$1"
  for ex in "${EXCLUDE_PATHS[@]}"; do
    [[ "$p" == "$ex"* ]] && return 0
  done
  return 1
}

relpath_from_abs() {
  local abs="$1"
  abs="${abs#/}"
  echo "files/$abs"
}

file_hash() {
  sha256sum "$1" | awk '{print $1}'
}

is_secret_file() {
  case "$1" in
    */github_backup.env|*/s3_backup.env) return 0 ;;
    *) return 1 ;;
  esac
}
 
########################################
# 7) RETENTION (ALWAYS RUN)
########################################
retention_deleted=0
if [[ -d "$ENV_DIR" ]]; then
  # Only delete folders that look like dates
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    # Never touch latest
    [[ "$(basename "$d")" == "latest" ]] && continue

    # Only act on YYYY-MM-DD or YYYY-MM-DD_HHMMSS
    base="$(basename "$d")"
    if [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(_[0-9]{6})?$ ]]; then
      if find "$d" -maxdepth 0 -type d -mtime +"$RETENTION_DAYS" >/dev/null 2>&1; then
        echo "Retention: deleting old snapshot folder: $d"
        rm -rf "$d"
        retention_deleted=1
      fi
    fi
  done < <(find "$ENV_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null || true)
fi

########################################
# 8) COLLECT FILES
########################################
TMP_LIST="$(mktemp)"
CRON_TMP_DIR="$(mktemp -d)"
STAGE_LATEST="$(mktemp -d)"
STAGE_DATE="$(mktemp -d)"
NEW_MANIFEST="$(mktemp)"

cleanup() {
  rm -f "$TMP_LIST" "$NEW_MANIFEST" || true
  rm -rf "$CRON_TMP_DIR" "$STAGE_LATEST" "$STAGE_DATE" || true
}
trap cleanup EXIT

echo "Collecting candidate files (scripts + configs)..."

for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  is_excluded_path "$root" && continue

  find "$root" -type f -name "*.sh" 2>/dev/null >> "$TMP_LIST" || true
  for ext in "${CONFIG_EXTS[@]}"; do
    find "$root" -type f -iname "*.${ext}" 2>/dev/null >> "$TMP_LIST" || true
  done
done

sort -u "$TMP_LIST" -o "$TMP_LIST"
echo "Found $(wc -l < "$TMP_LIST" | tr -d ' ') candidate files."

########################################
# 9) COLLECT CRONS (READABLE ONLY)
########################################
echo "Collecting crons (readable only)..."

mkdir -p "$CRON_TMP_DIR"

# User crontab
if crontab -l >/dev/null 2>&1; then
  crontab -l > "$CRON_TMP_DIR/user_crontab.txt"
else
  echo "# No user crontab for $(whoami) on $(hostname) at $(date -Is)" > "$CRON_TMP_DIR/user_crontab.txt"
fi

# System cron files (best-effort)
[[ -r /etc/crontab ]] && cp -f /etc/crontab "$CRON_TMP_DIR/etc_crontab" || \
  echo "# /etc/crontab not readable on $(hostname) at $(date -Is)" > "$CRON_TMP_DIR/etc_crontab"

if [[ -d /etc/cron.d ]]; then
  mkdir -p "$CRON_TMP_DIR/etc_cron_d"
  while IFS= read -r -d '' f; do
    [[ -r "$f" ]] || continue
    cp -f "$f" "$CRON_TMP_DIR/etc_cron_d/$(basename "$f")" || true
  done < <(find /etc/cron.d -maxdepth 1 -type f -print0 2>/dev/null || true)
fi

for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
  if [[ -d "$d" ]]; then
    sub="$(basename "$d")"
    mkdir -p "$CRON_TMP_DIR/$sub"
    while IFS= read -r -d '' f; do
      [[ -r "$f" ]] || continue
      cp -f "$f" "$CRON_TMP_DIR/$sub/$(basename "$f")" || true
    done < <(find "$d" -maxdepth 1 -type f -print0 2>/dev/null || true)
  fi
done

########################################
# 10) CHANGE DETECTION (MANIFEST-BASED)
########################################
declare -A prev_hash
if [[ -f "$MANIFEST" ]]; then
  while read -r h p; do
    [[ -n "$h" && -n "$p" ]] || continue
    prev_hash["$p"]="$h"
  done < "$MANIFEST"
fi

changed_count=0

track_file() {
  local src="$1"
  local rel="$2"

  [[ -r "$src" ]] || return 0

  local h
  h="$(file_hash "$src")"
  echo "$h  $rel" >> "$NEW_MANIFEST"

  local prev="${prev_hash[$rel]:-}"
  if [[ "$h" != "$prev" ]]; then
    changed_count=$((changed_count + 1))

    mkdir -p "$STAGE_LATEST/$(dirname "$rel")"
    cp -f "$src" "$STAGE_LATEST/$rel"

    mkdir -p "$STAGE_DATE/$(dirname "$rel")"
    cp -f "$src" "$STAGE_DATE/$rel"
  fi
}

echo "Detecting changes..."
while IFS= read -r abs; do
  [[ -n "$abs" ]] || continue
  is_excluded_path "$abs" && continue
  is_secret_file "$abs" && continue
  track_file "$abs" "$(relpath_from_abs "$abs")"
done < "$TMP_LIST"

while IFS= read -r -d '' f; do
  rel="crons/${f#$CRON_TMP_DIR/}"
  track_file "$f" "$rel"
done < <(find "$CRON_TMP_DIR" -type f -print0 2>/dev/null || true)

sort -u "$NEW_MANIFEST" -o "$NEW_MANIFEST"

########################################
# 11) APPLY CHANGES INTO REPO
########################################
if [[ "$changed_count" -gt 0 ]]; then
  echo "Changes detected: $changed_count changed files."

  mkdir -p "$DATE_DIR"
  rsync -a "$STAGE_LATEST/" "$LATEST_DIR/"
  rsync -a "$STAGE_DATE/" "$DATE_DIR/"
  cp -f "$NEW_MANIFEST" "$MANIFEST"
else
  echo "No changes detected (uploads skipped)."
fi

########################################
# 12) COMMIT & PUSH (ONLY IF NEEDED)
########################################
git add "$ENV_DIR" || true

if git diff --cached --quiet; then
  if [[ "$retention_deleted" -eq 1 ]]; then
    # Retention deleted folders, but it might not have staged (edge case)
    git add "$ENV_DIR" || true
  fi
fi

if git diff --cached --quiet; then
  echo "Nothing to commit."
  echo "DONE: $(date -Is)"
  exit 0
fi

git commit -m "[$ENV_NAME] backup update $(date -Is)" >/dev/null
git push --quiet

echo "================================================================================"
echo "DONE: $(date -Is)"
echo "Committed changes. Changed files: $changed_count | Retention deletions: $retention_deleted"
echo "================================================================================"

################################################################################
# Notes:
# - Run this script via ec2-user cron (not root).
# - Token file: github_backup.env should be chmod 600 and only readable by the
#   cron user.
# - Logs are in: <script_dir>/logs/github_backup.log (use logrotate if desired).
################################################################################
