#!/bin/bash
# Rsync file transfer with retry logic for PDS backup
# Source this file to use: source "$(dirname "$0")/transfer.sh"

ensure_remote_dir() {
    local dest_user="$1"
    local dest_ip="$2"
    local dest_dir="$3"
    local log_file="$4"

    ssh "$dest_user@$dest_ip" "mkdir -p '$dest_dir'" 2>> "$log_file"
    return $?
}

transfer_with_retry() {
    local archive_file="$1"
    local dest_user="$2"
    local dest_ip="$3"
    local dest_dir="$4"
    local log_file="$5"
    local max_retries="${6:-3}"
    local retry_interval="${7:-60}"

    local attempt=1
    while [ $attempt -le $max_retries ]; do
        echo "$(date): Attempt $attempt to perform backup transfer using rsync..." >> "$log_file"

        if rsync -avz --remove-source-files "$archive_file" "$dest_user@$dest_ip:$dest_dir/" 2>> "$log_file"; then
            echo "$(date): Backup transfer completed successfully to $dest_dir" >> "$log_file"
            return 0
        else
            echo "$(date): ERROR: Backup transfer failed during rsync operation. Attempt $attempt of $max_retries." >> "$log_file"
            if [ $attempt -lt $max_retries ]; then
                echo "$(date): Retrying in $retry_interval seconds..." >> "$log_file"
                sleep "$retry_interval"
            fi
        fi
        ((attempt++))
    done

    echo "$(date): ERROR: Backup failed after $max_retries attempts." >> "$log_file"
    return 1
}
