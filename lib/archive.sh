#!/bin/bash
# Archive creation and checksum utilities for PDS backup
# Source this file to use: source "$(dirname "$0")/archive.sh"

create_archive() {
    local source_dir="$1"
    local archive_file="$2"
    local log_file="$3"

    tar -czf "$archive_file" -C "$source_dir" . 2>> "$log_file"
    return $?
}

get_checksum() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

get_remote_checksum() {
    local dest_user="$1"
    local dest_ip="$2"
    local remote_file="$3"

    ssh "$dest_user@$dest_ip" "sha256sum '$remote_file'" 2>/dev/null | awk '{print $1}'
}

find_latest_remote_archive() {
    local dest_user="$1"
    local dest_ip="$2"
    local dest_base_dir="$3"

    local latest_dir
    latest_dir=$(ssh "$dest_user@$dest_ip" "ls -dt $dest_base_dir/*/ 2>/dev/null | head -n 1")
    if [ -z "$latest_dir" ]; then
        echo ""
        return
    fi

    ssh "$dest_user@$dest_ip" "find $latest_dir -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | head -n 1"
}

check_for_changes() {
    local new_archive="$1"
    local dest_user="$2"
    local dest_ip="$3"
    local dest_base_dir="$4"
    local log_file="$5"

    local latest_archive
    latest_archive=$(find_latest_remote_archive "$dest_user" "$dest_ip" "$dest_base_dir")

    if [ -z "$latest_archive" ]; then
        echo "$(date): No previous backup archive found. First-time use detected. Skipping change detection." >> "$log_file"
        return 1  # Changes detected (no previous backup)
    fi

    local new_checksum remote_checksum
    new_checksum=$(get_checksum "$new_archive")
    remote_checksum=$(get_remote_checksum "$dest_user" "$dest_ip" "$latest_archive")

    echo "$(date): New archive checksum: $new_checksum" >> "$log_file"
    echo "$(date): Latest backup archive checksum: $remote_checksum" >> "$log_file"

    if [ "$new_checksum" = "$remote_checksum" ]; then
        echo "$(date): No changes detected since the last backup." >> "$log_file"
        return 0  # No changes
    else
        echo "$(date): Changes detected." >> "$log_file"
        return 1  # Changes detected
    fi
}
