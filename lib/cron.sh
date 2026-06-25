#!/bin/bash
# Crontab management utilities for PDS backup
# Source this file to use: source "$(dirname "$0")/cron.sh"

# ── Crontab management ──────────────────────────────────────────

# Idempotent cron replacement: remove all entries referencing this script,
# then re-add only the specified schedule. This prevents duplicate entries
# accumulating across runs.
ensure_cron_jobs() {
    local script_path="$1"
    local log_file="$2"
    shift 2
    local cron_jobs=("$@")

    # Strip any existing entries for this script path
    crontab -l 2>/dev/null | grep -v "$script_path" | crontab -

    # Install each desired schedule
    for job in "${cron_jobs[@]}"; do
        (crontab -l 2>/dev/null; echo "$job") | crontab -
        echo "$(date): Cron job '$job' added to crontab." >> "$log_file"
    done
}
