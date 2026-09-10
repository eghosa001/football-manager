#!/usr/bin/env bash
set -euo pipefail
script=${1:?Usage: test-headless.sh tests/suite.gd [timeout_seconds]}
seconds=${2:-600}
if (( $# >= 2 )); then shift 2; else shift; fi
log=$(mktemp)
trap 'rm -f "$log"' EXIT
if [[ "$script" == import ]]; then
  timeout "${seconds}s" godot --headless --editor --path . --import --quit 2>&1 | tee "$log"
else
  timeout "${seconds}s" godot --headless --path . --script "res://$script" "$@" 2>&1 | tee "$log"
fi
if grep -Eq 'SCRIPT ERROR:|ERROR:|Assertion failed' "$log"; then
  echo "Godot reported errors in $script" >&2
  exit 1
fi
if [[ "$script" != import ]]; then grep -q 'PASS' "$log"; fi
