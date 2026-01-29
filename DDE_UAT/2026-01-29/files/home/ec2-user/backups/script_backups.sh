#!/bin/bash
cd backups/

# List of files and directories to include in the zip
PATHS=("~/versioning/" "~/healthchecks/" "~/backups/script_backups.sh")  # Add your paths here

# Name of the backup directory
BACKUP_DIR="./script_backups/"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")  # Current timestamp for unique zip file names

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Loop through each path
for ITEM in "${PATHS[@]}"; do
    # Expand ~ to the user's home directory
    EXPANDED_ITEM=$(eval echo "$ITEM")

    if [[ -d "$EXPANDED_ITEM" ]]; then
        # Handle directory
        ITEM_NAME=$(basename "$EXPANDED_ITEM")
        ZIP_NAME="backup_${ITEM_NAME}_${TIMESTAMP}.zip"
        echo "Creating zip archive for directory: $EXPANDED_ITEM"
        zip -r "${BACKUP_DIR}/${ZIP_NAME}" "$EXPANDED_ITEM"

        if [[ $? -eq 0 ]]; then
            echo "Backup completed successfully for directory: $ITEM_NAME."
            echo "Archive saved to: ${BACKUP_DIR}/${ZIP_NAME}"
        else
            echo "Backup failed for directory: $ITEM_NAME."
        fi
    elif [[ -f "$EXPANDED_ITEM" ]]; then
        # Handle individual file
        ITEM_NAME=$(basename "$EXPANDED_ITEM")
        ZIP_NAME="backup_${ITEM_NAME}_${TIMESTAMP}.zip"
        echo "Creating zip archive for file: $EXPANDED_ITEM"
        zip "${BACKUP_DIR}/${ZIP_NAME}" "$EXPANDED_ITEM"

        if [[ $? -eq 0 ]]; then
            echo "Backup completed successfully for file: $ITEM_NAME."
            echo "Archive saved to: ${BACKUP_DIR}/${ZIP_NAME}"
        else
            echo "Backup failed for file: $ITEM_NAME."
        fi
    else
        echo "Skipping non-existent path: $ITEM"
    fi
done
