#!/usr/bin/env bash
# run_alu.sh: compile alu RTL + sample testbench with Icarus, run it, and exit nonzero on FAIL.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -lt 1 ]; then
    echo "usage: bash scripts/run_alu.sh <your_alu.sv> [vectors.txt]" >&2
    echo "  e.g. bash scripts/run_alu.sh results/alu/final_rtl.sv vectors/sample/alu_sample.txt" >&2
    exit 2
fi

DUT="$1"
VECTORS="${2:-$ROOT/vectors/sample/alu_sample.txt}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
mkdir -p "$BUILD_DIR"

echo "DUT:     $DUT"
echo "Vectors: $VECTORS"

iverilog -g2012 -s alu_tb -o "$BUILD_DIR/alu_tb.vvp" "$DUT" "$ROOT/testbench/alu_tb.sv"

# Capture output so we can key the exit status on the functional PASS/FAIL,
# not just the simulator's process exit (which is 0 even when the testbench prints FAIL).
OUT="$(vvp "$BUILD_DIR/alu_tb.vvp" "+VECTORS=$VECTORS")"
echo "$OUT"

# A run is a pass only if the final self-check line is exactly PASS with no FAIL present.
if echo "$OUT" | grep -q "^FAIL$" || ! echo "$OUT" | grep -q "^PASS$"; then
    echo ">>> RESULT: FAIL"
    exit 1
fi
echo ">>> RESULT: PASS"
