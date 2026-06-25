#!/bin/bash
# PDS Backup — modular backup script for AT Protocol PDS
# Orchestrates backup using sourced library modules from lib/

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
SOURCE_DIR="/pds"
DEST_USER=""
DEST_IP=""
DEST_BASE_DIR=""
MAX_RETRIES=3
RETRY_INTERVAL=60
RETENTION_DAYS=30

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/lib"

# Source library modules
source "$LIB_DIR/network.sh"
source "$LIB_DIR/service.sh"
source "$LIB_DIR/archive.sh"
source "$LIB_DIR/transfer.sh"
source "$LIB_DIR/cleanup.sh"
source "$LIB_DIR/cron.sh"

# ── Derived variables ──────────────────────────────────────────
LOG_DIR="$SCRIPT_DIR/logs/pds-backup"
DATE_LABEL=$(date +"%Y%m%d-%H%M")
LOG_FILE="$LOG_DIR/$DATE_LABEL.log"
DEST_DIR="${DEST_BASE_DIR}/${DATE_LABEL}"
ARCHIVE_FILE="$SCRIPT_DIR/${DATE_LABEL}.tar.gz"
CRON_JOBS=(
    "0 12 * * * /bin/bash $(realpath "$0")"
    "0 0 * * * /bin/bash $(realpath "$0")"
)

# ── Helpers ────────────────────────────────────────────────────
fail() {
    echo "$(date): ERROR: $1" | tee -a "$LOG_FILE"
    start_pds >> "$LOG_FILE" 2>&1 || true
    exit 1
}

# ── Main ───────────────────────────────────────────────────────
main() {
    mkdir -p "$LOG_DIR"

    # Step 0: Network check
    echo "$(date): Checking if machine at $DEST_IP is online..." >> "$LOG_FILE"
    if ! check_connectivity "$DEST_IP"; then
        fail "Machine at $DEST_IP is unreachable."
    fi
    echo "$(date): Machine at $DEST_IP is online." >> "$LOG_FILE"

    # Step 1: Verify PDS service exists
    echo "$(date): Checking PDS service status..." >> "$LOG_FILE"
    if ! pds_service_exists; then
        fail "PDS service not found."
    fi

    # Step 2: Stop PDS
    echo "$(date): Stopping the PDS service..." >> "$LOG_FILE"
    stop_pds >> "$LOG_FILE" 2>&1 || echo "$(date): WARNING: Failed to stop PDS. Proceeding anyway." >> "$LOG_FILE"

    # Step 3: Create archive
    echo "$(date): Creating compressed backup archive of $SOURCE_DIR..." >> "$LOG_FILE"
    if ! create_archive "$SOURCE_DIR" "$ARCHIVE_FILE" "$LOG_FILE"; then
        fail "Failed to create the backup archive."
    fi
    echo "$(date): Archive created successfully at $ARCHIVE_FILE." >> "$LOG_FILE"

    # Step 3.1: Check for changes
    echo "$(date): Checking for differences with the latest backup..." >> "$LOG_FILE"
    if check_for_changes "$ARCHIVE_FILE" "$DEST_USER" "$DEST_IP" "$DEST_BASE_DIR" "$LOG_FILE"; then
        echo "No changes detected since the last backup. Backup not performed." | tee -a "$LOG_FILE"
        start_pds >> "$LOG_FILE" 2>&1 && echo "$(date): Successfully restarted the PDS service." >> "$LOG_FILE"
        exit 0
    fi

    # Step 4: Ensure remote directory
    echo "$(date): Ensuring destination directory $DEST_DIR exists..." >> "$LOG_FILE"
    if ! ensure_remote_dir "$DEST_USER" "$DEST_IP" "$DEST_DIR" "$LOG_FILE"; then
        fail "Failed to create destination directory $DEST_DIR."
    fi
    echo "$(date): Destination directory $DEST_DIR is ready." >> "$LOG_FILE"

    # Step 5: Transfer with retry
    if ! transfer_with_retry "$ARCHIVE_FILE" "$DEST_USER" "$DEST_IP" "$DEST_DIR" "$LOG_FILE" "$MAX_RETRIES" "$RETRY_INTERVAL"; then
        fail "Backup transfer failed after $MAX_RETRIES attempts."
    fi

    # Step 6: Clean up local archive
    echo "$(date): Deleting local archive $ARCHIVE_FILE..." >> "$LOG_FILE"
    rm -f "$ARCHIVE_FILE"
    echo "$(date): Local archive deleted successfully." >> "$LOG_FILE"

    # Step 7: Restart PDS
    echo "$(date): Restarting the PDS service..." >> "$LOG_FILE"
    if ! start_pds >> "$LOG_FILE" 2>&1; then
        fail "Failed to start the PDS service."
    fi

    # Step 8: Cleanup old backups
    echo "$(date): Deleting backup directories older than $RETENTION_DAYS days..." >> "$LOG_FILE"
    if delete_old_backups "$DEST_USER" "$DEST_IP" "$DEST_BASE_DIR" "$RETENTION_DAYS" "$LOG_FILE"; then
        echo "$(date): Deleted old backup directories successfully." >> "$LOG_FILE"
    else
        echo "$(date): ERROR: Failed to delete old backup directories." >> "$LOG_FILE"
    fi

    # Step 9: Log rotation
    rotate_old_logs "$LOG_DIR" "$LOG_FILE"

    # Step 10: Ensure cron jobs
    ensure_cron_jobs "$(realpath "$0")" "$LOG_FILE" "${CRON_JOBS[@]}"

    echo "$(date): Backup and service restart completed successfully." >> "$LOG_FILE"
    exit 0
}

main
