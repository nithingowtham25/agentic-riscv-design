#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROVIDER="${1:-tamu}"
MODEL="${2:-gpt-5.4}"
mkdir -p results/terminal_logs
log="results/terminal_logs/task1_agent_sanity_$(date +%Y%m%d_%H%M%S).log"
{
  echo "=== Task 1C Verification Agent sanity run ==="
  date -Is
  python agent/run_agent.py --provider "$PROVIDER" --out results --core core --max-calls 1 --model "$MODEL"
  echo "=== Generated-test replay required by Task 1C ==="
  python harness/run.py --tests results/tests --core core/datapath_pipelined.sv
} 2>&1 | tee "$log"
echo "Terminal log: $log"