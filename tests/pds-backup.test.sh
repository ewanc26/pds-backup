#!/bin/bash
# Regression tests for pds-backup.sh
#
# Covers the no-change branch of main(): it must restart the PDS and only report
# success when the restart actually succeeds (issue #3).
#
# Usage: bash tests/pds-backup.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_SCRIPT="$REPO_DIR/pds-backup.sh"

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
}

# Run main() through the "no changes" branch with start_pds stubbed to return
# $1 (0 = success, non-zero = failure). Prints the exit code, then the log.
run_no_change_case() {
    local start_rc="$1"
    local tmp
    tmp="$(mktemp -d)"

    (
        set +e
        # shellcheck source=/dev/null
        source "$BACKUP_SCRIPT" >/dev/null 2>&1

        LOG_DIR="$tmp/logs"
        LOG_FILE="$LOG_DIR/test.log"
        SOURCE_DIR="$tmp/data"
        ARCHIVE_FILE="$tmp/archive.tar.gz"
        DEST_USER="backup"
        DEST_IP="10.255.255.1"
        DEST_BASE_DIR="/remote/backups"

        # Stub every side-effecting dependency; create_archive stays real so the
        # archive file actually exists when the no-change branch runs.
        check_connectivity() { return 0; }
        pds_service_exists() { return 0; }
        stop_pds() { return 0; }
        check_for_changes() { return 0; }
        start_pds() { return "$start_rc"; }

        mkdir -p "$LOG_DIR" "$SOURCE_DIR"
        echo "data" > "$SOURCE_DIR/file.txt"

        # main() calls exit, so run it in a nested subshell to capture the code.
        # The sourced script re-enables set -e, so disable it again before
        # running main or a non-zero exit would kill this subshell too.
        set +e
        ( set +e; main >"$tmp/stdout.log" 2>&1 )
        echo "__RC__$?"
        if [ -e "$ARCHIVE_FILE" ]; then echo "__ARCHIVE__present"; else echo "__ARCHIVE__absent"; fi
        echo "__LOG__"
        cat "$LOG_FILE" 2>/dev/null
    )

    rm -rf "$tmp"
}

echo "pds-backup regression tests"

echo
echo "no-change branch: successful restart"
OUT="$(run_no_change_case 0)"
RC="$(printf '%s\n' "$OUT" | sed -n 's/^__RC__//p')"
if [ "$RC" = "0" ]; then
    pass "exits 0 when the PDS restarts"
else
    fail "expected exit 0 when the PDS restarts, got $RC"
fi
if printf '%s\n' "$OUT" | grep -q "Successfully restarted the PDS service"; then
    pass "logs a successful restart"
else
    fail "expected a successful-restart log line"
fi
if printf '%s\n' "$OUT" | grep -q "^__ARCHIVE__absent$"; then
    pass "removes the local archive when nothing changed"
else
    fail "expected the local archive to be removed after an unchanged run"
fi

echo
echo "no-change branch: failed restart (issue #3)"
OUT="$(run_no_change_case 1)"
RC="$(printf '%s\n' "$OUT" | sed -n 's/^__RC__//p')"
if [ "$RC" != "0" ] && [ -n "$RC" ]; then
    pass "exits non-zero when the PDS restart fails"
else
    fail "expected a non-zero exit when the PDS restart fails, got '$RC'"
fi
if printf '%s\n' "$OUT" | grep -q "ERROR: Failed to restart PDS after an unchanged backup."; then
    pass "logs the restart failure"
else
    fail "expected the restart failure to be logged"
fi

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
