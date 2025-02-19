#!/bin/bash

# Variables
SOURCE_DIR="/pds"  # Path to your PDS directory
DEST_USER=""  # Username on the destination machine
DEST_IP=""  # IP address of the destination machine
DEST_BASE_DIR=""  # Base destination directory on the destination machine
SCRIPT_DIR="$(dirname "$(realpath "$0")")"  # Base directory of the script
LOG_DIR="$SCRIPT_DIR/logs/pds-backup"  # Log directory for the backup logs
DATE_LABEL=$(date +"%Y%m%d-%H%M")  # Date label (e.g., "20250216-1944")
LOG_FILE="$LOG_DIR/$DATE_LABEL.log"  # Log file for backup status
DEST_DIR="${DEST_BASE_DIR}/${DATE_LABEL}"  # Destination directory with date-time label
ARCHIVE_FILE="$SCRIPT_DIR/${DATE_LABEL}.tar.gz"  # Local archive file path
MAX_RETRIES=3  # Maximum retries for backup
RETRY_INTERVAL=60  # Retry interval in seconds (1 minute)
CRON_JOBS=("0 12 * * * /bin/bash $(realpath "$0")" "0 0 * * * /bin/bash $(realpath "$0")")  # Cron jobs for the backup script

# Helper function for error logging and exit
fail() {
    echo "$(date): ERROR: $1" | tee -a "$LOG_FILE"
    # Always restart the PDS service if it fails
    systemctl restart pds 2>/dev/null || echo "$(date): WARNING: Failed to restart PDS service after failure." >> "$LOG_FILE"
    exit 1
}

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Step 0: Check if the destination machine is reachable by pinging
echo "$(date): Checking if machine at $DEST_IP is online..." >> "$LOG_FILE"
if ! ping -c 1 "$DEST_IP" &>/dev/null; then
    fail "Machine at $DEST_IP is unreachable. Exiting the script."
fi
echo "$(date): Machine at $DEST_IP is online." >> "$LOG_FILE"

# Step 1: Ensure the PDS service exists and is either running or stopped
echo "$(date): Checking PDS service status..." >> "$LOG_FILE"
if ! systemctl list-units --full -all | grep -Fq "pds.service"; then
    fail "PDS service not found. Exiting."
fi

# Step 2: Stop the PDS service (if applicable)
echo "$(date): Stopping the PDS service..." >> "$LOG_FILE"
if ! systemctl stop pds 2>/dev/null; then
    echo "$(date): WARNING: Failed to stop the PDS service. Proceeding with backup." >> "$LOG_FILE"
else
    echo "$(date): Successfully stopped the PDS service." >> "$LOG_FILE"
fi

# Step 3: Create a compressed archive of the PDS directory
echo "$(date): Creating a compressed backup archive of $SOURCE_DIR..." >> "$LOG_FILE"
tar -czf "$ARCHIVE_FILE" -C "$SOURCE_DIR" . 2>> "$LOG_FILE"
if [ $? -eq 0 ]; then
    echo "$(date): Archive created successfully at $ARCHIVE_FILE." >> "$LOG_FILE"
else
    fail "Failed to create the backup archive. Exiting."
fi

# Step 3.1: Check for differences with the latest backup archive
echo "$(date): Checking for differences between the new archive and the latest backup archive..." >> "$LOG_FILE"
LATEST_BACKUP_DIR=$(ssh "$DEST_USER@$DEST_IP" "ls -dt $DEST_BASE_DIR/*/ 2>/dev/null | head -n 1")
if [ -z "$LATEST_BACKUP_DIR" ]; then
    echo "$(date): No previous backup directory found. First-time use detected. Skipping change detection." >> "$LOG_FILE"
else
    LATEST_ARCHIVE_FILE=$(ssh "$DEST_USER@$DEST_IP" "find $LATEST_BACKUP_DIR -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | head -n 1")
    if [ -z "$LATEST_ARCHIVE_FILE" ]; then
        echo "$(date): No previous backup archive found in $LATEST_BACKUP_DIR. First-time use detected. Skipping change detection." >> "$LOG_FILE"
    else
        NEW_CHECKSUM=$(sha256sum "$ARCHIVE_FILE" | awk '{print $1}')
        REMOTE_CHECKSUM=$(ssh "$DEST_USER@$DEST_IP" "sha256sum '$LATEST_ARCHIVE_FILE'" 2>/dev/null | awk '{print $1}')
        echo "$(date): New archive checksum: $NEW_CHECKSUM" >> "$LOG_FILE"
        echo "$(date): Latest backup archive checksum: $REMOTE_CHECKSUM" >> "$LOG_FILE"
        if [ "$NEW_CHECKSUM" = "$REMOTE_CHECKSUM" ]; then
            echo "$(date): No changes detected since the last backup. Skipping backup transfer." >> "$LOG_FILE"
            echo "No changes detected since the last backup. Backup not performed." | tee -a "$LOG_FILE"
            # Restart PDS service before exiting
            systemctl start pds 2>/dev/null && echo "$(date): Successfully restarted the PDS service." >> "$LOG_FILE"
            exit 0
        else
            echo "$(date): Changes detected. Proceeding with backup transfer." >> "$LOG_FILE"
        fi
    fi
fi

# Step 4: Ensure the destination directory exists, create if not
echo "$(date): Ensuring destination directory $DEST_DIR exists..." >> "$LOG_FILE"
ssh "$DEST_USER@$DEST_IP" "mkdir -p '$DEST_DIR'" 2>> "$LOG_FILE"
if [ $? -eq 0 ]; then
    echo "$(date): Destination directory $DEST_DIR is ready." >> "$LOG_FILE"
else
    fail "Failed to create destination directory $DEST_DIR. Exiting."
fi

# Step 5: Perform the transfer of the archive to the destination machine using rsync with retry mechanism
attempt=1
while [ $attempt -le $MAX_RETRIES ]; do
    echo "$(date): Attempt $attempt to perform backup transfer using rsync..." >> "$LOG_FILE"

    if rsync -avz --remove-source-files "$ARCHIVE_FILE" "$DEST_USER@$DEST_IP:$DEST_DIR/" 2>> "$LOG_FILE"; then
        echo "$(date): Backup transfer completed successfully to $DEST_DIR" >> "$LOG_FILE"
        break
    else
        echo "$(date): ERROR: Backup transfer failed during rsync operation. Attempt $attempt of $MAX_RETRIES." >> "$LOG_FILE"
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "$(date): Retrying in $RETRY_INTERVAL seconds..." >> "$LOG_FILE"
            sleep $RETRY_INTERVAL
        else
            echo "$(date): ERROR: Backup failed after $MAX_RETRIES attempts." >> "$LOG_FILE"
            fail "Backup transfer failed after $MAX_RETRIES attempts. Check logs and network connection."
        fi
    fi
    ((attempt++))
done

# Step 6: Delete the local archive after successful transfer
echo "$(date): Deleting local archive $ARCHIVE_FILE..." >> "$LOG_FILE"
rm -f "$ARCHIVE_FILE"
echo "$(date): Local archive deleted successfully." >> "$LOG_FILE"

# Step 7: Always restart the PDS service (if applicable)
echo "$(date): Restarting the PDS service..." >> "$LOG_FILE"
if ! systemctl start pds 2>/dev/null; then
    fail "Failed to start the PDS service. Check service status and logs."
fi
echo "$(date): Successfully restarted the PDS service." >> "$LOG_FILE"

# Step 8: Delete backup directories older than 30 days
echo "$(date): Checking and deleting backup directories older than 30 days..." >> "$LOG_FILE"
ssh "$DEST_USER@$DEST_IP" "find $DEST_BASE_DIR -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;" 2>> "$LOG_FILE"
if [ $? -eq 0 ]; then
    echo "$(date): Deleted backup directories older than 30 days successfully." >> "$LOG_FILE"
else
    echo "$(date): ERROR: Failed to delete old backup directories. Check logs for details." >> "$LOG_FILE"
fi

# Step 9: Log Rotation - Delete logs older than 90 days and rotate the log file
echo "$(date): Checking the size and age of the log file..." >> "$LOG_FILE"

# Delete log files older than 90 days
find "$LOG_DIR" -type f -name "*.log" -mtime +90 -exec rm -f {} \; 2>/dev/null
echo "$(date): Deleted log files older than 90 days." >> "$LOG_FILE"

# Check if the log file is older than 30 days
if [ $(find "$LOG_FILE" -mtime +30 -print) ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
    touch "$LOG_FILE"
    echo "$(date): Log file older than 30 days, rotated. Previous log archived as $LOG_FILE.old" >> "$LOG_FILE"
fi

# Check if the log file exceeds 1000 lines (adjust size threshold if necessary)
if [ $(wc -l < "$LOG_FILE") -gt 1000 ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
    touch "$LOG_FILE"
    echo "$(date): Log file exceeded 1000 lines, rotated. Previous log archived as $LOG_FILE.old" >> "$LOG_FILE"
fi

# Step 10: Ensure only the specified cron jobs are present in crontab for this script
# Remove all existing cron jobs related to this script
crontab -l | grep -v "$(realpath "$0")" | crontab -

# Add only the desired cron jobs
for job in "${CRON_JOBS[@]}"; do
    # Add the job to the crontab
    (crontab -l; echo "$job") | crontab -
    echo "$(date): Cron job '$job' added to crontab." >> "$LOG_FILE"
done

# Completion log
echo "$(date): Backup and service restart completed successfully." >> "$LOG_FILE"
exit 0