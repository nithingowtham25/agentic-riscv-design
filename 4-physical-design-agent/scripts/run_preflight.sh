#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p output/terminal_logs
log="output/terminal_logs/preflight_$(date +%Y%m%d_%H%M%S).log"
{ echo '=== Assignment 4 environment preflight ==='; date -Is; bash check_environment.sh; } 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
echo "Terminal log: $log"
exit "$status"
