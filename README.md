# PDS Backup Script

***This repository is available on [GitHub](https://github.com/ewanc26/pds-backup) and [Tangled](https://tangled.sh/did:plc:ofrbh253gwicbkc5nktqepol/pds-backup). GitHub is the primary version, and the Tangled version is a mirror.***

## Overview

This Bash script automates the backup process for your Personal Data Server (PDS) files. It ensures minimal downtime by managing the PDS service—stopping it before a backup and restarting it afterwards—even in the event of errors. The script creates a timestamped compressed archive of the `/pds` directory, then transfers this archive to a remote destination via `rsync` over SSH. A change detection mechanism compares the new archive against the most recent backup using a SHA-256 checksum; if no changes are detected, the transfer is skipped, thereby preventing redundant backups.

Additionally, the script incorporates a retry mechanism for the transfer process, automatically attempting up to three retries at 60-second intervals if the initial `rsync` operation fails. Detailed logs are maintained in a `logs/pds-backup` folder relative to the script's base directory, with an automated log rotation policy based on both file age and size. The script also updates the system’s crontab to schedule automated backups twice daily—at midnight and at noon.

## Features

- **Service Management:**  
  The script stops the PDS service before creating a backup and ensures it is restarted afterwards. In case of an error during any step, the script attempts to restart the PDS service automatically to minimise downtime.

- **Backup Archive Creation:**  
  A timestamped `.tar.gz` archive is generated from the `/pds` directory, providing a consistent snapshot of your data.

- **Change Detection:**  
  The newly created archive is compared with the latest remote backup archive using SHA-256 checksums. If the checksums match (indicating no changes), the backup transfer is skipped. This mechanism is bypassed on the first run if no previous backup is found.

- **Reliable Remote Transfer:**  
  The archive is transferred to the remote machine via `rsync` over SSH. A maximum of three transfer attempts are made, with a 60-second interval between retries.

- **Directory and Log Management:**  
  The script verifies the existence of the remote destination directory (creating it if necessary) and cleans up remote backup directories older than 30 days. Locally, log files are rotated when they exceed 1000 lines or are older than 30 days, with files older than 90 days being automatically deleted.

- **Cron Job Setup:**  
  Upon each run, the script updates the crontab to ensure that backup jobs are scheduled at midnight and noon daily, maintaining only the specified cron entries.

## Requirements

- **PDS Installation:**  
  A working PDS installation is required. For installation instructions, refer to the [PDS repository](https://github.com/bluesky-social/pds).

- **SSH Access:**  
  Passwordless SSH must be configured between the source and destination machines. You can set this up by following these steps:

  1. Generate an SSH key pair (if not already done):

     ```bash
     ssh-keygen -t ed25519
     ```
  
  2. Copy the public key to the destination machine:

     ```bash
     ssh-copy-id <DEST_USER>@<DEST_IP>
     ```
  
  3. Test the SSH connection to verify it's working without prompting for a password:

     ```bash
     ssh <DEST_USER>@<DEST_IP>
     ```

- **Systemd:**  
  The script utilises `systemctl` to manage the PDS service, thus requiring a system that supports systemd.

- **Root Privileges:**  
  The script must be executed with root privileges (e.g. via `sudo`).

## Configuration

Before using the script, update the following variables within the script to suit your environment:

- `SOURCE_DIR`: The directory where your PDS files are stored (default: `/pds`).
- `DEST_USER`: The username for the destination machine.
- `DEST_IP`: The IP address of the destination machine.  

  **Example:**

  ```bash
  DEST_IP="<DEST_IP>"  # Replace with your destination IP address
  ```

- `DEST_BASE_DIR`: The base directory on the destination machine where backups will be stored.  
  **Example:**  

  ```bash
  DEST_BASE_DIR="/path/to/remote/backup"  # Replace with your desired remote backup directory
  ```

Additional parameters such as `MAX_RETRIES`, `RETRY_INTERVAL`, and the `CRON_JOBS` array can be adjusted as necessary.

## How It Works

1. **Destination Check:**  
   The script begins by pinging the remote machine to ensure it is online.

2. **Service Verification and Stopping:**  
   It confirms the presence of the PDS service and stops it gracefully.

3. **Backup Archive Creation:**  
   A compressed archive of the `/pds` directory is created, timestamped with the current date and time.

4. **Change Detection:**  
   The new archive’s SHA-256 checksum is compared against that of the latest remote backup archive. If no differences are found, the backup transfer is skipped.

5. **Remote Directory Setup:**  
   If a backup transfer is necessary, the script ensures the remote destination directory (named with the current timestamp) exists.

6. **Archive Transfer with Retry Mechanism:**  
   The archive is transferred via `rsync`. The script makes up to three attempts, with a 60-second pause between retries, if an error occurs.

7. **Local and Remote Cleanup:**  
   After a successful transfer, the local archive is deleted. Additionally, remote backup directories older than 30 days are removed.

8. **Log Rotation:**  
   Log files are maintained in the `logs/pds-backup` directory, rotated if they exceed 1000 lines or are older than 30 days, and logs older than 90 days are purged.

9. **Cron Job Installation:**  
   The script updates the crontab to schedule automated backups at midnight and at noon each day.

## Usage

1. **Manual Execution:**  
   Run the script manually from the command line:

   ```bash
   sudo ./pds-backup.sh
   ```

2. **Automated Backups:**  
   The script automatically sets up cron jobs to execute the backup twice daily.

3. **Monitoring Logs:**  
   Review the logs in the `logs/pds-backup` folder for detailed information about each backup operation:

   ```bash
   tail -f /path/to/script/logs/pds-backup/20250216-1944.log
   ```

## Troubleshooting

If the script repeatedly fails during the `rsync` transfer, check the logs for errors related to network issues, SSH connectivity, or disk space problems. Logs can be found in:

```bash
tail -f /path/to/script/logs/pds-backup/*.log
```

Additionally, ensure the destination server has enough disk space to store the backup:

```bash
df -h
```

## Disk Space Warning

Make sure there is enough space on the destination machine for the backup archive. You may want to periodically check available space:

```bash
df -h
```

## Backup Retention Policy

The script automatically deletes backup directories on the destination machine that are older than 30 days. If you need to retain backups for a longer period, you can adjust the retention policy in the script. Specifically, this line:

```bash
ssh "$DEST_USER@$DEST_IP" "find $DEST_BASE_DIR -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;" 2>> "$LOG_FILE"
```

## Notes

- Ensure that passwordless SSH is properly configured between your source and destination machines.
- Verify that you have sufficient disk space on the destination machine for backups.
- It is advisable to test the script manually prior to relying solely on the automated cron jobs.
- In the event of an error, the script logs the issue and makes every effort to restart the PDS service, thereby maintaining service continuity.
