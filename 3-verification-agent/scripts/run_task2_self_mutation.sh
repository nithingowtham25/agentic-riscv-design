#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p results/terminal_logs
log="results/terminal_logs/task2_self_mutation_$(date +%Y%m%d_%H%M%S).log"
{
  echo "=== Task 2 self-mutation validation ==="
  date -Is
  python agent/self_mutate.py --out results --core core
} 2>&1 | tee "$log"
echo "Terminal log: $log"