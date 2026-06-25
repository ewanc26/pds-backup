#!/bin/bash
# Cleanup and log rotation utilities for PDS backup
# Source this file to use: source "$(dirname "$0")/cleanup.sh"

delete_old_backups() {
    local dest_user="$1"
    local dest_ip="$2"
    local dest_base_dir="$3"
    local retention_days="${4:-30}"
    local log_file="$5"

    ssh "$dest_user@$dest_ip" \
        "find $dest_base_dir -mindepth 1 -maxdepth 1 -type d -mtime +$retention_days -exec rm -rf {} \;" \
        2>> "$log_file"
    return $?
}

rotate_old_logs() {
    local log_dir="$1"
    local log_file="$2"

    # Delete logs older than 90 days
    find "$log_dir" -type f -name "*.log" -mtime +90 -exec rm -f {} \; 2>/dev/null
    echo "$(date): Deleted log files older than 90 days." >> "$log_file"

    # Rotate if older than 30 days
    if [ -n "$(find "$log_file" -mtime +30 -print 2>/dev/null)" ]; then
        mv "$log_file" "$log_file.old"
        touch "$log_file"
        echo "$(date): Log file older than 30 days, rotated. Previous log archived as $log_file.old" >> "$log_file"
    fi

    # Rotate if exceeds 1000 lines
    if [ -f "$log_file" ] && [ "$(wc -l < "$log_file")" -gt 1000 ]; then
        mv "$log_file" "$log_file.old"
        touch "$log_file"
        echo "$(date): Log file exceeded 1000 lines, rotated. Previous log archived as $log_file.old" >> "$log_file"
    fi
}
