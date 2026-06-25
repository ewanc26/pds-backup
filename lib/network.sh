#!/bin/bash
# Network connectivity utilities for PDS backup
# Source this file to use: source "$(dirname "$0")/network.sh"

check_connectivity() {
    local dest_ip="$1"
    if ! ping -c 1 "$dest_ip" &>/dev/null; then
        return 1
    fi
    return 0
}
