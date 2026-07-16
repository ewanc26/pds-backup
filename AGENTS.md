# AGENTS.md

Guidance for agents working on the Bash PDS backup utility.

## Safety-critical behavior

- `pds-backup.sh` orchestrates stop, archive, checksum comparison, rsync transfer, retention, scheduling, logging, and restart. Shared helpers live in `lib/`.
- The PDS must be restarted even after archive or transfer failure. Preserve traps and test every exit path.
- A backup is not successful until archive creation, integrity checking, and remote transfer/verification complete.
- Quote paths, reject unsafe/empty destinations, avoid `eval`, and prevent retention logic from deleting outside the configured backup namespace.
- Never place SSH keys, host credentials, PDS secrets, or archive contents in Git or logs.
- Crontab edits must be idempotent and preserve unrelated entries.

## Validation

Run `bash -n` and `shellcheck` on all shell files. Test with mocked `systemctl`/service, `tar`, `rsync`, `ssh`, checksums, and crontab in temporary directories. Cover unchanged data, retry success/exhaustion, low disk, interrupted archive, remote failure, retention boundaries, paths with spaces, and guaranteed restart. A live restore test on disposable data is stronger evidence than archive existence alone.
