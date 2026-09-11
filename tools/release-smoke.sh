#!/usr/bin/env bash
# Shared release-smoke helper. One implementation for every workflow.
# Usage: release-smoke.sh <binary> <logfile> [timeout_seconds]
set -euo pipefail
binary=${1:?Usage: release-smoke.sh <binary> <logfile>}
logfile=${2:?Usage: release-smoke.sh <binary> <logfile>}
seconds=${3:-180}
mkdir -p "$(dirname "$logfile")"
timeout "${seconds}s" "$binary" --headless -- --release-smoke 2>&1 | tee "$logfile"
if grep -Eq 'SCRIPT ERROR:|ERROR:' "$logfile"; then
  echo "release smoke found engine errors in $logfile" >&2
  exit 1
fi
grep -q 'RELEASE SMOKE PASS' "$logfile"
