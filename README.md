# PDS Backup Script

## Overview

Bash script that automates PDS backups. Stops the PDS service, creates a timestamped `.tar.gz` archive of `/pds`, transfers it via `rsync` over SSH, then restarts the service — even if something fails midway.

Change detection compares the new archive against the last remote backup with SHA-256; if nothing changed, the transfer is skipped. Up to three retries at 60-second intervals if `rsync` fails. Logs go to `logs/pds-backup/` with automatic rotation by age and size. Updates crontab for twice-daily backups (midnight and noon).

> 🧶 Also available on [Tangled](https://tangled.org/ewancroft.uk/pds-backup)

## Features

- **Service management** — Stops the PDS before backup, restarts it after. If something fails, it still tries to restart the service.
- **Archive** — Timestamped `.tar.gz` of `/pds`.
- **Change detection** — Compares SHA-256 checksums with the latest remote backup. Skips transfer if nothing changed. Bypassed on first run.
- **Transfer** — `rsync` over SSH. Up to 3 retries, 60 seconds apart.
- **Cleanup** — Creates remote dirs if needed. Remotes older than 30 days get deleted. Logs rotate at 1000 lines or 30 days; anything over 90 days is purged.
- **Cron** — Sets up backups at midnight and noon on each run.

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
- If an error occurs, the script logs it and tries to restart the PDS service so it stays running.

## ☕ Support

If you found this useful, consider [buying me a ko-fi](https://ko-fi.com/ewancroft)!
