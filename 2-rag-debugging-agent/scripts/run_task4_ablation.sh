#!/usr/bin/env bash
# Task 4: controlled three-run ablation. Requires a prior Task 3 rtl_good_backup snapshot.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVIDER="${1:-tamu}"
MODEL="${2:-gpt-5.4}"
cd "$ROOT"
test -f rtl_good_backup/datapath.sv || { echo 'Missing rtl_good_backup/datapath.sv; complete Task 3 first.' >&2; exit 2; }
mkdir -p logs/ablation
for arm in baseline rag rag_feedback; do
    for run in 1 2 3; do
        rm -f rtl/datapath.sv
        python agent/run_debug_agent.py --module datapath --arm "$arm" --provider "$PROVIDER" --model "$MODEL" --log-file "logs/ablation/part_a_${arm}_${run}.json" || true
    done
done
for arm in rag rag_feedback; do
    for run in 1 2 3; do
        rm -f rtl/datapath.sv
        python agent/run_debug_agent.py --module datapath --arm "$arm" --provider "$PROVIDER" --model "$MODEL" --seed-rtl bugs/datapath_buggy.sv --log-file "logs/ablation/part_b_${arm}_${run}.json" || true
    done
done