#!/bin/bash

# Variables - Update these with your specific paths and credentials
SOURCE_DIR="/pds"  # Path to your PDS directory
DEST_USER="your_username"  # Username for the destination machine
DEST_IP="your.destination.ip"  # IP address of the destination machine
DEST_BASE_DIR="/path/to/backup/storage"  # Base destination directory on the destination machine
LOG_FILE="/var/log/pds-backup.log"  # Log file for backup status
DATE_LABEL=$(date +"%Y%m%d-%H%M")  # Date label (e.g., "20241103-1830")
DEST_DIR="${DEST_BASE_DIR}/${DATE_LABEL}"  # Destination directory with date-time label

# Helper function for error logging and exit
fail() {
    echo "$(date): ERROR: $1" | tee -a "$LOG_FILE"
    exit 1
}

# Step 1: Stop the PDS service (if applicable)
if ! systemctl stop pds 2>/dev/null; then
    fail "Failed to stop the PDS service. Check permissions or service status."
fi
echo "$(date): Successfully stopped the PDS service." >> "$LOG_FILE"

# Step 2: Perform the backup using rsync to a date-time labelled folder
if ! rsync -avz --delete "$SOURCE_DIR/" "$DEST_USER@$DEST_IP:$DEST_DIR/" 2>> "$LOG_FILE"; then
    echo "$(date): ERROR: Backup failed during rsync operation. Check connection, permissions, and disk space." | tee -a "$LOG_FILE"

    # Attempt to restart PDS if rsync fails
    if systemctl start pds 2>/dev/null; then
        echo "$(date): PDS service restarted after failed backup." >> "$LOG_FILE"
    else
        echo "$(date): WARNING: Failed to restart PDS service after rsync failure." >> "$LOG_FILE"
    fi
    exit 1
fi
echo "$(date): Backup completed successfully to $DEST_DIR" >> "$LOG_FILE"

# Step 3: Restart the PDS service (if applicable)
if ! systemctl start pds 2>/dev/null; then
    fail "Failed to start the PDS service. Check service status and logs."
fi
echo "$(date): Successfully restarted the PDS service." >> "$LOG_FILE"

# Completion log
echo "$(date): Backup and service restart completed successfully." >> "$LOG_FILE"
