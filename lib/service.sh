#!/bin/bash
# Systemd service management for PDS backup
# Source this file to use: source "$(dirname "$0")/service.sh"

pds_service_exists() {
    systemctl list-units --full -all | grep -Fq "pds.service"
}

stop_pds() {
    if systemctl stop pds 2>/dev/null; then
        echo "$(date): Successfully stopped the PDS service."
        return 0
    else
        echo "$(date): WARNING: Failed to stop the PDS service."
        return 1
    fi
}

start_pds() {
    if systemctl start pds 2>/dev/null; then
        echo "$(date): Successfully restarted the PDS service."
        return 0
    else
        echo "$(date): WARNING: Failed to restart PDS service."
        return 1
    fi
}
