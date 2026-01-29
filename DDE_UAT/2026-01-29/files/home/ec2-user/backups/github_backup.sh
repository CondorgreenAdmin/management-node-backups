################################################################################
# Condorgreen Management Node Backup Script
#
# Backs up:
#   - All *.sh scripts
#   - Selected config files
#   - FULL cron configuration
#
# Pushes backups to GitHub:
#   - Per environment folder
#   - latest/ snapshot (never deleted)
#   - dated folders (only changed files)
#   - 3 month retention on dated folders
#
# Authentication:
#   - GitHub token is read from /etc/mgmt-node-backups.env
#
################################################################################

########################################
# 1) REQUIRED CONFIGURATION (EDIT THIS)
########################################

# >>> CHANGE THIS PER NODE <<<
ENV_NAME="DDE_UAT"

# GitHub repo details
GITHUB_ORG="condorgreen"
GITHUB_REPO="management-node-backups"
GITHUB_BRANCH="main"

########################################
# 2) FIXED SETTINGS (DO NOT OVERTHINK)
########################################

WORKDIR="/var/tmp/mgmt-node-backup-repo"
LOG_DIR="/var/log/mgmt-node-backups"
LOG_FILE="$LOG_DIR/github_backup.log"
RETENTION_DAYS=93   # ~3 months

SEARCH_ROOTS=(
  "/home"
  "/opt"
  "/usr/local/bin"
  "/etc"
)

CONFIG_EXTS=(
  "conf" "cfg" "cnf" "ini" "yaml" "yml" "json" "env" "properties"
)

EXCLUDE_PATHS=(
  "/proc" "/sys" "/dev" "/run" "/var/lib" "/var/cache" "/var/tmp"
)

########################################
# 3) LOAD GITHUB TOKEN (NO ENV VARS)
########################################

TOKEN_FILE="/etc/mgmt-node-backups.env"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "ERROR: Token file $TOKEN_FILE not found"
  exit 1
fi

# shellcheck source=/etc/mgmt-node-backups.env
source "$TOKEN_FILE"

if [[ -z "${BACKUP_STORE:-}" ]]; then
  echo "ERROR: BACKUP_STORE not set in $TOKEN_FILE"
  exit 1
fi

########################################
# 4) BASIC SAFETY CHECKS
########################################

ALLOWED_ENVS=(
  "DDE_UAT" "DDE_PROD"
  "PFP_UAT" "PFP_PROD"
  "BM_NONPROD" "BM_PREPROD" "BM_PROD"
)

if [[ ! " ${ALLOWED_ENVS[*]} " =~ " ${ENV_NAME} " ]]; then
  echo "ERROR: ENV_NAME '$ENV_NAME' is not allowed"
  exit 1
fi

command -v git >/dev/null || { echo "git not installed"; exit 1; }

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== START $(date -Is) | ENV=$ENV_NAME ====="

########################################
# 5) PREPARE GIT REPO
########################################

GIT_URL="https://${BACKUP_STORE}@github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"

if [[ ! -d "$WORKDIR/.git" ]]; then
  rm -rf "$WORKDIR"
  git clone "$GIT_URL" "$WORKDIR"
fi

cd "$WORKDIR"
git checkout "$GITHUB_BRANCH"
git pull --rebase

########################################
# 6) DIRECTORY STRUCTURE
########################################

ENV_DIR="$ENV_NAME"
LATEST_DIR="$ENV_DIR/latest"
DATE_DIR="$ENV_DIR/$(date +%F)"
MANIFEST="$LATEST_DIR/.manifest.sha256"

mkdir -p "$LATEST_DIR"

########################################
# 7) HELPER FUNCTIONS
########################################

is_excluded() {
  for e in "${EXCLUDE_PATHS[@]}"; do
    [[ "$1" == "$e"* ]] && return 0
  done
  return 1
}

relpath() {
  echo "files/${1#/}"
}

hash_file() {
  sha256sum "$1" | awk '{print $1}'
}

########################################
# 8) COLLECT FILES
########################################

TMP_LIST="$(mktemp)"

for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  is_excluded "$root" && continue
  find "$root" -type f -name "*.sh" 2>/dev/null >> "$TMP_LIST"
  for ext in "${CONFIG_EXTS[@]}"; do
    find "$root" -type f -iname "*.${ext}" 2>/dev/null >> "$TMP_LIST"
  done
done

sort -u "$TMP_LIST" -o "$TMP_LIST"

########################################
# 9) COLLECT FULL CRONS
########################################

CRON_TMP="$(mktemp -d)"
mkdir -p "$CRON_TMP"

crontab -l 2>/dev/null > "$CRON_TMP/user_crontab.txt" || true
[[ -r /etc/crontab ]] && cp /etc/crontab "$CRON_TMP/etc_crontab" || true
[[ -d /etc/cron.d ]] && cp -r /etc/cron.d "$CRON_TMP/cron_d" || true
for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
  [[ -d "$d" ]] && cp -r "$d" "$CRON_TMP/"
done

########################################
# 10) CHANGE DETECTION
########################################

declare -A OLD_HASH
[[ -f "$MANIFEST" ]] && while read -r h p; do OLD_HASH["$p"]="$h"; done < "$MANIFEST"

STAGE_LATEST="$(mktemp -d)"
STAGE_DATE="$(mktemp -d)"
NEW_MANIFEST="$(mktemp)"
CHANGED=0

track() {
  local src="$1" rel="$2"
  [[ -r "$src" ]] || return
  local h; h=$(hash_file "$src")
  echo "$h  $rel" >> "$NEW_MANIFEST"
  if [[ "${OLD_HASH[$rel]:-}" != "$h" ]]; then
    CHANGED=$((CHANGED + 1))
    mkdir -p "$STAGE_LATEST/$(dirname "$rel")"
    mkdir -p "$STAGE_DATE/$(dirname "$rel")"
    cp -f "$src" "$STAGE_LATEST/$rel"
    cp -f "$src" "$STAGE_DATE/$rel"
  fi
}

while read -r f; do
  is_excluded "$f" && continue
  track "$f" "$(relpath "$f")"
done < "$TMP_LIST"

while IFS= read -r -d '' f; do
  track "$f" "crons/${f#$CRON_TMP/}"
done < <(find "$CRON_TMP" -type f -print0)

sort -u "$NEW_MANIFEST" -o "$NEW_MANIFEST"

########################################
# 11) APPLY CHANGES
########################################

if [[ "$CHANGED" -eq 0 ]]; then
  echo "No changes detected"
  exit 0
fi

mkdir -p "$DATE_DIR"
rsync -a "$STAGE_LATEST/" "$LATEST_DIR/"
rsync -a "$STAGE_DATE/" "$DATE_DIR/"
cp -f "$NEW_MANIFEST" "$MANIFEST"

########################################
# 12) RETENTION (DATED FOLDERS ONLY)
########################################

find "$ENV_DIR" -maxdepth 1 -type d -name "????-??-??" -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;

########################################
# 13) COMMIT & PUSH
########################################

git add "$ENV_DIR"
git commit -m "[$ENV_NAME] backup update $(date -Is)"
git push

echo "===== DONE $(date -Is) ====="
