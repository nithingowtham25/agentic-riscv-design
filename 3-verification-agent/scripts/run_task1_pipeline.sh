#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p results/terminal_logs
log="results/terminal_logs/task1_pipeline_$(date +%Y%m%d_%H%M%S).log"
{
  echo "=== Task 1 pipeline regression ==="
  date -Is
  python harness/run.py --tests harness/task1_tests --core core/datapath_pipelined.sv
} 2>&1 | tee "$log"
echo "Terminal log: $log"