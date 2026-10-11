#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p results/terminal_logs
log="results/terminal_logs/final_assertion_check_$(date +%Y%m%d_%H%M%S).log"
{
  echo "=== Final generated-suite and assertion check ==="
  date -Is
  python harness/run.py --tests results/tests --assertions results/assertions.sv --core core/datapath_pipelined.sv
} 2>&1 | tee "$log"
echo "Terminal log: $log"