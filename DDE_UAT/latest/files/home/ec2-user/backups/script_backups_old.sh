#!/bin/bash

# List of folders to include in the zip
FOLDERS=("~/versioning/" "~/healthchecks/" "~/backups/script_backups.sh")  # Add your folders here

# Name of the backup directory
BACKUP_DIR="./script_backups/"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")  # Current timestamp for unique zip file names

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Loop through each folder
for FOLDER in "${FOLDERS[@]}"; do
    # Expand ~ to the user's home directory
    EXPANDED_FOLDER=$(eval echo "$FOLDER")

    if [[ -d "$EXPANDED_FOLDER" ]]; then
        # Extract the folder name from the path
        FOLDER_NAME=$(basename "$EXPANDED_FOLDER")

        # Set the zip file name
        ZIP_NAME="backup_${FOLDER_NAME}_${TIMESTAMP}.zip"

        # Create the zip archive
        echo "Creating zip archive for: $EXPANDED_FOLDER"
        zip -r "${BACKUP_DIR}/${ZIP_NAME}" "$EXPANDED_FOLDER"

        if [[ $? -eq 0 ]]; then
            echo "Backup completed successfully for $FOLDER_NAME."
            echo "Archive saved to: ${BACKUP_DIR}/${ZIP_NAME}"
        else
            echo "Backup failed for $FOLDER_NAME."
        fi
    else
        echo "Skipping non-existent folder: $FOLDER"
    fi
done
