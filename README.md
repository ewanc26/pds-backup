# PDS Backup Script

## Overview
This Bash script is designed to automate the backup process of [PDS (Personal Data Server)](https://github.com/bluesky-social/pds) files to a remote machine using `rsync`. The script stops the PDS service, creates a backup with a timestamp, and restarts the service upon completion.

***This script is not affiliated with Bluesky PBLLC.***

This backup process is manual and is intended to be run only when desired. The script logs all actions and errors to a specified log file.

## Requirements
- **A working PDS**: Make sure to actually have a PDS, obviously. Go to the [PDS (Personal Data Server)](https://github.com/bluesky-social/pds) repository to see the install instructions.
- **SSH Access**: The script uses `rsync` over SSH to transfer files. Ensure passwordless SSH is configured between the source and destination machines.
- **Service Control**: The script relies on `systemctl` to start and stop the PDS service. Ensure the PDS service is managed by `systemctl` on the source machine.
- **Disk Space**: Ensure sufficient space is available on the destination machine to store backups.
- **Sudo**: Ability to run in root. ***The script requires the use of `sudo`.*** 

## Variables and Configuration
Edit the following variables in the script to suit your environment:

- `SOURCE_DIR`: The directory on the source machine where PDS files are stored.
- `DEST_USER`: Username for accessing the destination machine.
- `DEST_IP`: IP address of the destination machine.
- `DEST_BASE_DIR`: Base directory on the destination machine where backups are stored.
- `LOG_FILE`: Location of the log file where backup logs will be saved.
  
**Example:**
```bash
SOURCE_DIR="/pds"
DEST_USER="username"
DEST_IP="destination.ip.address"
DEST_BASE_DIR="/path/to/destination/folder"
LOG_FILE="/var/log/pds-backup.log"
```

## How It Works
1. **Stop PDS Service**: The script attempts to stop the PDS service on the source machine.
2. **Create a Backup**: Using `rsync`, the script transfers files from the source directory to the destination directory, organized by a timestamp.
3. **Restart PDS Service**: After the backup, the script restarts the PDS service.
4. **Error Handling**: In case of failure during `rsync`, the script logs an error, restarts the PDS service, and exits.

## Usage
1. **Run the Script Manually**:
   Execute the script manually *from* the PDS by running:
   ```bash
   sudo ./pds-backup.sh
   ```

2. **Check the Log File**:
   Backup progress and errors are logged in the specified log file. Check this file to confirm the success of the backup or to troubleshoot any issues:
   ```bash
   tail -f /var/log/pds-backup.log
   ```

## Example Log Entries
- Successful stop of the PDS service:
  ```
  YYYY-MM-DD HH:MM: Successfully stopped the PDS service.
  ```
- Successful completion of backup:
  ```
  YYYY-MM-DD HH:MM: Backup completed successfully to /destination/path/YYYYMMDD-HHMM
  ```
- Failure messages:
  ```
  YYYY-MM-DD HH:MM: ERROR: Backup failed during rsync operation. Check connection, permissions, and disk space.
  ```
