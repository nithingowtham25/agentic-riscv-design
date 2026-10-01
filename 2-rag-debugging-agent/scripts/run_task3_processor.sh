#!/usr/bin/env bash
# Task 3 steps 1, 3, 4, and 5. Run after scripts/copy_a1_rtl.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVIDER="${1:-tamu}"
MODEL="${2:-gpt-5.4}"
cd "$ROOT"
mkdir -p logs
for module in pc_unit branch_unit memory_access; do
    python agent/run_debug_agent.py --module "$module" --arm rag_feedback --provider "$PROVIDER" --model "$MODEL" --log-file "logs/$module.json"
done
python agent/run_debug_agent.py --module datapath --arm rag_feedback --provider "$PROVIDER" --model "$MODEL" --log-file logs/datapath.json
bash scripts/run_all_sample.sh
rm -rf rtl_good_backup
cp -r rtl rtl_good_backup
printf 'Saved passing processor snapshot: %s/rtl_good_backup\n' "$ROOT"