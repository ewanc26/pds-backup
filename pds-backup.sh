#!/bin/bash

# Variables
SOURCE_DIR=""  # Path to your PDS directory
DEST_USER=""  # Username on the destination machine
DEST_IP=""  # IP address of the destination machine
DEST_BASE_DIR=""  # Base destination directory on the destination machine
LOG_FILE=""  # Log file for backup status
DATE_LABEL=$(date +"%Y%m%d-%H%M")  # Date label (e.g., "20241103-1830")
DEST_DIR="${DEST_BASE_DIR}/${DATE_LABEL}"  # Destination directory with date-time label
MAX_RETRIES=3  # Maximum retries for backup
RETRY_INTERVAL=60  # Retry interval in seconds (1 minute)

# Helper function for error logging and exit
fail() {
    echo "$(date): ERROR: $1" | tee -a "$LOG_FILE"
    # Always restart the PDS service if it fails
    systemctl restart pds 2>/dev/null || echo "$(date): WARNING: Failed to restart PDS service after failure." >> "$LOG_FILE"
    exit 1
}

# Step 0: Check if the destination machine is reachable by pinging
echo "$(date): Checking if machine at $DEST_IP is online..." >> "$LOG_FILE"
if ! ping -c 1 "$DEST_IP" &>/dev/null; then
    fail "Machine at $DEST_IP is unreachable. Exiting the script."
fi
echo "$(date): Machine at $DEST_IP is online." >> "$LOG_FILE"

# Step 1: Stop the PDS service (if applicable)
echo "$(date): Stopping the PDS service..." >> "$LOG_FILE"
if ! systemctl stop pds 2>/dev/null; then
    echo "$(date): WARNING: Failed to stop the PDS service. Proceeding with backup." >> "$LOG_FILE"
else
    echo "$(date): Successfully stopped the PDS service." >> "$LOG_FILE"
fi

# Step 2: Perform the backup using rsync with retry mechanism
attempt=1
while [ $attempt -le $MAX_RETRIES ]; do
    echo "$(date): Attempt $attempt to perform backup using rsync..." >> "$LOG_FILE"

    if rsync -avz --delete "$SOURCE_DIR/" "$DEST_USER@$DEST_IP:$DEST_DIR/" 2>> "$LOG_FILE"; then
        echo "$(date): Backup completed successfully to $DEST_DIR" >> "$LOG_FILE"
        break
    else
        echo "$(date): ERROR: Backup failed during rsync operation. Attempt $attempt of $MAX_RETRIES." >> "$LOG_FILE"
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "$(date): Retrying in $RETRY_INTERVAL seconds..." >> "$LOG_FILE"
            sleep $RETRY_INTERVAL
        else
            echo "$(date): ERROR: Backup failed after $MAX_RETRIES attempts." >> "$LOG_FILE"
            fail "Backup failed after $MAX_RETRIES attempts. Check logs and network connection."
        fi
    fi
    ((attempt++))
done

# Step 3: Always restart the PDS service (if applicable)
echo "$(date): Restarting the PDS service..." >> "$LOG_FILE"
if ! systemctl start pds 2>/dev/null; then
    fail "Failed to start the PDS service. Check service status and logs."
fi
echo "$(date): Successfully restarted the PDS service." >> "$LOG_FILE"

# Step 4: Log Rotation - Delete old log files (> 30 days)
echo "$(date): Checking and deleting log files older than 30 days..." >> "$LOG_FILE"
find /var/log/ -name "pds-backup*.log" -type f -mtime +30 -exec rm -f {} \; 2>/dev/null
echo "$(date): Deleted old log files older than 30 days." >> "$LOG_FILE"

# Step 5: Log Rotation - archive old log files to avoid large log size
if [ $(wc -l < "$LOG_FILE") -gt 1000 ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
    touch "$LOG_FILE"
    echo "$(date): Log file rotated. Previous log archived." >> "$LOG_FILE"
fi

# Completion log
echo "$(date): Backup and service restart completed successfully." >> "$LOG_FILE"