#!/usr/bin/env bash
# Task 3 step 6: repair every supplied seeded bug and retain one JSON record per module.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVIDER="${1:-tamu}"
MODEL="${2:-gpt-5.4}"
cd "$ROOT"
mkdir -p logs/seeded_repairs
for module in pc_unit branch_unit memory_access datapath; do
    python agent/run_debug_agent.py --module "$module" --arm rag_feedback --provider "$PROVIDER" --model "$MODEL" --seed-rtl "bugs/${module}_buggy.sv" --log-file "logs/seeded_repairs/${module}.json"
done