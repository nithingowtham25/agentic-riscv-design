#!/usr/bin/env bash
# Task 3 step 2: copy the selected Assignment 1 modules without changing their interfaces.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
A1_RTL_DIR="${1:?usage: bash scripts/copy_a1_rtl.sh /path/to/A1/final_rtl}"
for module in alu regfile extend controller; do
    test -f "$A1_RTL_DIR/$module.sv"
    cp "$A1_RTL_DIR/$module.sv" "$ROOT/rtl/$module.sv"
done
printf 'Copied Assignment 1 RTL modules into %s/rtl\n' "$ROOT"