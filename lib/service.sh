#!/bin/bash
# Systemd service management for PDS backup
# Source this file to use: source "$(dirname "$0")/service.sh"

# ── PDS service management ────────────────────────────────────────

# Confirm the PDS systemd unit exists before attempting stop/start
pds_service_exists() {
    systemctl list-units --full -all | grep -Fq "pds.service"
}

# Gracefully stop PDS so the archive gets a consistent filesystem snapshot
stop_pds() {
    if systemctl stop pds 2>/dev/null; then
        echo "$(date): Successfully stopped the PDS service."
        return 0
    else
        echo "$(date): WARNING: Failed to stop the PDS service."
        return 1
    fi
}

# Restart PDS after backup completes. Called from main() on success and from fail() on
# error -- we want service restored either way.
start_pds() {
    if systemctl start pds 2>/dev/null; then
        echo "$(date): Successfully restarted the PDS service."
        return 0
    else
        echo "$(date): WARNING: Failed to restart PDS service."
        return 1
    fi
}
