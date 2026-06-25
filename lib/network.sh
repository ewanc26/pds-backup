#!/bin/bash
# Network connectivity utilities for PDS backup
# Source this file to use: source "$(dirname "$0")/network.sh"

# Quick reachability check via ICMP. A single ping keeps it fast;
# we don't need a full TCP probe for a local-network backup target.
check_connectivity() {
    local dest_ip="$1"
    if ! ping -c 1 "$dest_ip" &>/dev/null; then
        return 1
    fi
    return 0
}
