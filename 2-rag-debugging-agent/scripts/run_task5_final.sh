#!/usr/bin/env bash
# Task 5: restore the Task 3 processor snapshot and rerun all integration programs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

test -d rtl_good_backup || {
    echo 'Missing rtl_good_backup; complete Task 3 first.' >&2
    exit 2
}

test ! -d rtl/rtl_good_backup || {
    echo 'Error: rtl_good_backup must remain at the package root, not inside rtl/.' >&2
    exit 2
}

cp rtl_good_backup/*.sv rtl/
mkdir -p logs
bash scripts/run_all_sample.sh 2>&1 | tee logs/task5_final_processor.log