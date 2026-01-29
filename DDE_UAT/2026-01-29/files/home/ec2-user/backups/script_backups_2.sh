#!/bin/bash
set -euo pipefail
################################################################################
#
# What this does:
# 1) Zips each "important" path listed in PATHS into a timestamped zip file
# 2) Exports cron info (where possible) into a backup folder
# 3) Optionally copies the important folders + cron exports into a local git repo
#    and pushes to GitHub (simple add/commit/push. Set ENABLE_GIT_PUSH=true to backup to github
#
# Backups are stored locally on the management node
################################################################################
# Always run relative to where this script lives (avoids "cd" problems)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# List of folders to back up
PATHS=("~/versioning/" "~/healthchecks/" "~/backups/script_backups.sh")
# Local backup destination (same area as current script, but new folder)
BACKUP_DIR="${SCRIPT_DIR}/backups_2"
ZIPS_DIR="${BACKUP_DIR}/zips"
CRON_DIR="${BACKUP_DIR}/crons"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
# Optional: GitHub backup (set ENABLE_GIT_PUSH=true to enable)
ENABLE_GIT_PUSH=true
# Where the local git repo lives (this folder should be a git repo with a remote)
# e.g. BACKUP_GIT_REPO="${SCRIPT_DIR}/backups_2_github_repo"
BACKUP_GIT_REPO="${SCRIPT_DIR}/backups_2_github_repo"
# Create backup folders
mkdir -p "$ZIPS_DIR" "$CRON_DIR"
echo "Backup started: ${TIMESTAMP}"
echo "Local backup folder: ${BACKUP_DIR}"
echo
################################################################################
# 1) ZIP backups for each path in PATHS
################################################################################
for ITEM in "${PATHS[@]}"; do
  # Expand ~ safely for these known static strings
  EXPANDED_ITEM=$(eval echo "$ITEM")
  if [[ -d "$EXPANDED_ITEM" ]]; then
    ITEM_NAME="$(basename "$EXPANDED_ITEM")"
    ZIP_NAME="backup_${ITEM_NAME}_${TIMESTAMP}.zip"
    echo "Zipping directory: $EXPANDED_ITEM"
    zip -r "${ZIPS_DIR}/${ZIP_NAME}" "$EXPANDED_ITEM" >/dev/null
    echo "  -> Saved: ${ZIPS_DIR}/${ZIP_NAME}"
    echo
  elif [[ -f "$EXPANDED_ITEM" ]]; then
    ITEM_NAME="$(basename "$EXPANDED_ITEM")"
    ZIP_NAME="backup_${ITEM_NAME}_${TIMESTAMP}.zip"
    echo "Zipping file: $EXPANDED_ITEM"
    zip "${ZIPS_DIR}/${ZIP_NAME}" "$EXPANDED_ITEM" >/dev/null
    echo "  -> Saved: ${ZIPS_DIR}/${ZIP_NAME}"
    echo
  else
    echo "Skipping non-existent path: $ITEM"
    echo
  fi
done
################################################################################
# 2) Cron backups
################################################################################
echo "Backing up cron info..."
# Current user's crontab
if crontab -l >/dev/null 2>&1; then
  crontab -l > "${CRON_DIR}/crontab_${USER}_${TIMESTAMP}.txt"
  echo "  -> Saved user crontab: ${CRON_DIR}/crontab_${USER}_${TIMESTAMP}.txt"
else
  echo "  -> No user crontab found for ${USER} (or crontab not accessible)."
fi
# System cron files (may require sudo depending on permissions)
# We'll copy what we can, and skip what we can't
SYSTEM_CRON_SOURCES=(
  "/etc/crontab"
  "/etc/cron.d"
  "/etc/cron.daily"
  "/etc/cron.hourly"
  "/etc/cron.weekly"
  "/etc/cron.monthly"
  "/var/spool/cron"
)
for SRC in "${SYSTEM_CRON_SOURCES[@]}"; do
  if [[ -e "$SRC" ]]; then
    # Try to copy. If permission denied, keep going.
    DEST="${CRON_DIR}/$(basename "$SRC")_${TIMESTAMP}"
    if cp -a "$SRC" "$DEST" 2>/dev/null; then
      echo "  -> Copied: $SRC  to  $DEST"
    else
      echo "  -> Could not copy (permission?): $SRC"
    fi
  fi
done
echo "Cron backup completed."
echo
################################################################################
# 3) Optional: Push to GitHub (simple)
################################################################################
if [[ "${ENABLE_GIT_PUSH}" == "true" ]]; then
  echo "GitHub backup enabled."
  # Basic checks
  if ! command -v git >/dev/null 2>&1; then
    echo "  -> git not found. Skipping GitHub backup."
  elif [[ ! -d "${BACKUP_GIT_REPO}" ]]; then
    echo "  -> Repo folder not found: ${BACKUP_GIT_REPO}"
    echo "     Create it and set it up as a git repo with a GitHub remote, then rerun."
  else
    # Create a clean structure inside the repo
    mkdir -p "${BACKUP_GIT_REPO}/important" "${BACKUP_GIT_REPO}/crons"
    # Copy important paths into the repo (scripts/configs only)
    # (We copy folders into 'important/' so the repo stays tidy)
    for ITEM in "${PATHS[@]}"; do
      EXPANDED_ITEM=$(eval echo "$ITEM")
      if [[ -d "$EXPANDED_ITEM" ]]; then
        ITEM_NAME="$(basename "$EXPANDED_ITEM")"
        echo "  -> Syncing folder into repo: $EXPANDED_ITEM"
        rsync -a --delete "${EXPANDED_ITEM%/}/" "${BACKUP_GIT_REPO}/important/${ITEM_NAME}/" >/dev/null 2>&1 || true
      elif [[ -f "$EXPANDED_ITEM" ]]; then
        echo "  -> Copying file into repo: $EXPANDED_ITEM"
        cp -a "$EXPANDED_ITEM" "${BACKUP_GIT_REPO}/important/" 2>/dev/null || true
      fi
    done
    # Copy cron exports into the repo
    echo "  -> Syncing cron exports into repo"
    rsync -a --delete "${CRON_DIR%/}/" "${BACKUP_GIT_REPO}/crons/" >/dev/null 2>&1 || true
    # Commit and push
    cd "${BACKUP_GIT_REPO}"
    # Only commit if there are changes
    if [[ -n "$(git status --porcelain)" ]]; then
      git add -A
      git commit -m "Management node scripts + cron backup ${TIMESTAMP}" >/dev/null
      # Push to default remote/branch (assumes already configured)
      git push >/dev/null
      echo "  -> GitHub push completed."
    else
      echo "  -> No changes detected; nothing to commit/push."
    fi
  fi
  echo
fi
echo "Backup finished: ${TIMESTAMP}"
