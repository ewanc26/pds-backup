# AGENTS.md

Guidance for agents working on this Bash backup utility for a systemd-managed AT Protocol PDS.

## Repository map and flow

- `pds-backup.sh` contains site configuration, derives timestamped local/remote paths, sources `lib/*.sh`, and orchestrates the run.
- `lib/network.sh` performs a one-packet ICMP reachability check; `service.sh` finds and stops/starts `pds.service`.
- `lib/archive.sh` creates a `.tar.gz`, locates the newest remote archive, and compares SHA-256 checksums.
- `lib/transfer.sh` creates the remote directory and retries `rsync` up to the configured limit.
- `lib/cleanup.sh` deletes old remote directories and rotates local logs; `lib/cron.sh` replaces entries referencing this exact script and installs midnight/noon jobs.

The current sequence is connectivity check, service check/stop, archive, remote checksum comparison, transfer, service restart, remote retention, log rotation, then cron installation. An unchanged archive restarts the service and exits before retention, rotation, or cron setup.

## Safety-critical current behaviour

- `DEST_USER`, `DEST_IP`, and `DEST_BASE_DIR` are empty placeholders in the tracked script. Configure and validate them before any live run. Empty or shell-sensitive remote paths are not rejected consistently, and several remote `find`/`ls` commands interpolate paths without robust shell quoting.
- `set -euo pipefail` is enabled, and explicit failures call `fail`, which tries to restart PDS. There is no `trap`; signals, shell termination, or an unexpected `set -e` exit can leave the service stopped. Add a single idempotent cleanup trap before claiming guaranteed restart.
- Failure to stop PDS is logged but the archive proceeds, so a backup may be taken from a live, changing data directory.
- Change detection compares the new compressed archive with the newest remote `.tar.gz`. It does not independently verify archive readability or restored contents. `rsync` success is treated as transfer success; there is no remote checksum-after-transfer or restore test.
- `rsync --remove-source-files` normally removes the local archive during transfer; the later `rm -f` is cleanup. Failed transfers can leave archives beside the script.
- Retention performs a remote `find ... -exec rm -rf`; guard an absolute, non-root backup namespace before changing or invoking it. Log rotation retains only one `.old` file per active log name.
- Crontab rewriting filters lines containing the absolute script path and then adds two jobs. Preserve unrelated entries and avoid partial crontab replacement on failure.
- Never commit SSH keys, PDS data, host secrets, generated archives, or logs.

## Validation

Run `bash -n pds-backup.sh lib/*.sh` and `shellcheck pds-backup.sh lib/*.sh`. There is no automated test harness. Exercise changes with mocked `ping`, `systemctl`, `tar`, `ssh`, `rsync`, `sha256sum`, and `crontab` on disposable directories, covering signals after service stop, unchanged data, retries, empty/unsafe destinations, retention boundaries, and preservation of unrelated cron entries. A successful archive command is not restore evidence; verify a transferred checksum and perform a disposable extraction/restore test before trusting operational changes.
