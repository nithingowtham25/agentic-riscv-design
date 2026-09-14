#!/usr/bin/env bash
# run_generated_tb.sh: compile a generated testbench against the generated RTL for one module and run it.
# run_generated_tb.sh: confirms YOUR Phase-B testbench passes/fails on YOUR Phase-A RTL (self-checking, no vectors).
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: bash run_generated_tb.sh <module> [results_dir]" >&2
    echo "  module: alu | regfile | extend | controller" >&2
    echo "  e.g. bash run_generated_tb.sh alu            # uses results/alu/" >&2
    echo "       bash run_generated_tb.sh alu results/alu" >&2
    exit 2
fi

MOD="$1"
DIR="${2:-results/$MOD}"
RTL="$DIR/final_rtl.sv"
TB="$DIR/${MOD}_tb.sv"
BUILD_DIR="${BUILD_DIR:-$DIR}"
VVP="$BUILD_DIR/gen_tb.vvp"

for f in "$RTL" "$TB"; do
    if [ ! -f "$f" ]; then
        echo "Missing $f - run lab1.py first to generate the RTL and testbench for '$MOD'." >&2
        exit 2
    fi
done

echo "RTL:       $RTL"
echo "Testbench: $TB"
mkdir -p "$BUILD_DIR"

# Compile the generated RTL together with the generated (self-checking) testbench.
iverilog -g2012 -o "$VVP" "$RTL" "$TB"

# The generated testbench drives its own stimulus and prints its own PASS/FAIL,
# so no external vectors are passed. Capture output to key the exit status on the
# functional result, not just the simulator process exit (which is 0 even on FAIL).
OUT="$(vvp "$VVP")"
echo "$OUT"

# A pass requires a PASS line and no FAIL line.
if echo "$OUT" | grep -q "FAIL" || ! echo "$OUT" | grep -q "PASS"; then
    echo ">>> RESULT: FAIL"
    exit 1
fi
echo ">>> RESULT: PASS"
