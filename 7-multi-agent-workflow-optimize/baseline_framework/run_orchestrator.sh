#!/usr/bin/env bash
# One-command, non-overwriting Assignment 6 run.
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$ROOT"
source scripts/activate_olympus_env.sh
run_id="a7_$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="workspace/runs/$run_id"
mkdir -p "$run_dir/reports"
echo "=== Assignment 7 orchestration ==="
echo "Run ID: $run_id"
echo "Run directory: $run_dir"
set +e
python3 tools/orchestrate.py --run-id "$run_id" "$@" 2>&1 | tee "$run_dir/reports/terminal_run.log"
status=${PIPESTATUS[0]}
set -e
echo "Terminal log: $run_dir/reports/terminal_run.log"
exit "$status"
