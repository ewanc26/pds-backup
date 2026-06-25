#!/bin/bash
# Crontab management utilities for PDS backup
# Source this file to use: source "$(dirname "$0")/cron.sh"

ensure_cron_jobs() {
    local script_path="$1"
    local log_file="$2"
    shift 2
    local cron_jobs=("$@")

    # Remove all existing cron jobs related to this script
    crontab -l 2>/dev/null | grep -v "$script_path" | crontab -

    # Add only the desired cron jobs
    for job in "${cron_jobs[@]}"; do
        (crontab -l 2>/dev/null; echo "$job") | crontab -
        echo "$(date): Cron job '$job' added to crontab." >> "$log_file"
    done
}
