#!/usr/bin/env bash
# Validate selected generated TBs using the supplied, unmodified runner.
# Generated TBs use a runner-compatible runtime protocol: passing output
# contains TESTS_ERRORS rather than the substring FAIL.
#
# Folder 2 is not modified.

set -uo pipefail

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$CODE_DIR/.." && pwd)"

RTL_DIR="$PROJECT_DIR/2_verilog_blocks_and_testbenches/final_rtl"
TB_DIR="$PROJECT_DIR/2_verilog_blocks_and_testbenches/final_tb"
RUNNER="$CODE_DIR/run_generated_tb.sh"

STAGE_ROOT="$CODE_DIR/results/final_validation/generated_tb"
LOG_DIR="$STAGE_ROOT/logs"

mkdir -p "$STAGE_ROOT" "$LOG_DIR"

BLOCKS=(alu regfile extend controller)

failed=0

for block in "${BLOCKS[@]}"; do

    src_rtl="$RTL_DIR/${block}.sv"
    src_tb="$TB_DIR/${block}_tb.sv"

    stage="$STAGE_ROOT/$block"
    log="$LOG_DIR/${block}.log"

    rm -rf "$stage"
    mkdir -p "$stage"

    echo
    echo "======================================================================"
    echo "GENERATED TB VALIDATION: $block"
    echo "======================================================================"
    echo "Source RTL : $src_rtl"
    echo "Source TB  : $src_tb"
    echo "Runner     : $RUNNER"
    echo "Stage dir  : $stage"
    echo "Log        : $log"
    echo

    # Check required files.
    if [ ! -f "$src_rtl" ]; then
        echo "ERROR: Missing final RTL: $src_rtl"
        failed=$((failed + 1))
        continue
    fi

    if [ ! -f "$src_tb" ]; then
        echo "ERROR: Missing final generated TB: $src_tb"
        failed=$((failed + 1))
        continue
    fi

    if [ ! -f "$RUNNER" ]; then
        echo "ERROR: Missing supplied runner: $RUNNER"
        failed=$((failed + 1))
        continue
    fi

    # The supplied run_generated_tb.sh expects these exact filenames.
    cp "$src_rtl" "$stage/final_rtl.sv"
    cp "$src_tb" "$stage/${block}_tb.sv"

    # The generated TB protocol forbids the substring "FAIL" on a passing run,
    # so the supplied runner's exit code is now reliable and authoritative.
    if (
        cd "$CODE_DIR" &&
        bash "$RUNNER" "$block" "$stage"
    ) 2>&1 | tee "$log"; then
        echo "[${block}] PASS"
    else
        echo "[${block}] FAIL"
        failed=$((failed + 1))
    fi
done

echo
echo "======================================================================"
echo "GENERATED TB VALIDATION SUMMARY"
echo "======================================================================"

if [ "$failed" -eq 0 ]; then
    echo "All four final generated TBs passed against their selected final RTL."
    exit 0
else
    echo "$failed generated testbench validation(s) failed."
    exit 1
fi
