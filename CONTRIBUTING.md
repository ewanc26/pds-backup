# Contributing to pds-backup

Bash script that automates AT Protocol PDS backups: it stops the PDS service, creates a timestamped `.tar.gz` archive of `/pds`, transfers it via `rsync` over SSH, then restarts the service — even if something fails midway. Thanks for wanting to help!

This is operational tooling that runs as root against live servers, so robustness beats cleverness here.

## Getting started

```bash
git clone https://github.com/ewanc26/pds-backup.git
```

Read the [README](README.md) for requirements (a working PDS install,passwordless SSH to the destination, systemd, root) and test any change **against a throwaway PDS** before touching a real one.

## Notes for this project

- **The restart guarantee is the whole point.** Whatever you change, the PDS must still come back up after a failure mid-script. Preserve the trap/cleanup logic.
- Test `set -euo pipefail` behaviour: half-failed states are the interesting ones, not the happy path.
- Change detection uses SHA-256 against the last remote backup; retry logic is 3 attempts, 60 seconds apart. Keep those behaviours explicit and observable in the logs.
- Shellcheck-clean your change before opening a PR.
- Conventional commits; focused PRs; describe what you verified (ideally: a full backup-restore cycle against a test PDS).
- AI-assisted PRs welcome; stand behind every line and actually run the script logic.

## Licence

See [LICENSE](LICENSE). Contributions accepted under the same terms.