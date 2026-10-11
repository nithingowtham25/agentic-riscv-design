#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROVIDER="${1:-tamu}"
MODEL="${2:-gpt-5.4}"
MAX_CALLS="${3:-2}"
mkdir -p results/terminal_logs
log="results/terminal_logs/tasks2to4_agent_$(date +%Y%m%d_%H%M%S).log"
{
  echo "=== Tasks 2-4 verification agent ==="
  date -Is
  python agent/run_agent.py --provider "$PROVIDER" --out results --core core --max-calls "$MAX_CALLS" --model "$MODEL"
} 2>&1 | tee "$log"
echo "Terminal log: $log"