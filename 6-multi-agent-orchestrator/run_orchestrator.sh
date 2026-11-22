#!/usr/bin/env bash
# One-command Assignment 6 run. The sourced setup script prompts securely for the TAMU key.
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$ROOT"
source scripts/activate_olympus_env.sh
mkdir -p workspace/reports
log="workspace/reports/terminal_run_$(date -u +%Y%m%dT%H%M%SZ).log"
set +e
python3 tools/orchestrate.py "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e
echo "Terminal log: $log"
exit "$status"