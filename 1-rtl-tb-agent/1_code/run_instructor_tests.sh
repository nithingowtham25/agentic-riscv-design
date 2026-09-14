#!/usr/bin/env bash
# Validate the selected final RTL files with the original instructor
# testbench/sample-test flow. The instructor TBs are NOT copied or modified.
set -uo pipefail

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$CODE_DIR/.." && pwd)"
RTL_DIR="$PROJECT_DIR/2_verilog_blocks_and_testbenches/final_rtl"
LOG_DIR="$CODE_DIR/results/final_validation/instructor"
mkdir -p "$LOG_DIR"

BLOCKS=(alu regfile extend controller)
failed=0

for block in "${BLOCKS[@]}"; do
    rtl="$RTL_DIR/${block}.sv"
    script="$CODE_DIR/module_packages/$block/scripts/run_${block}.sh"
    log="$LOG_DIR/${block}.log"

    echo
    echo "======================================================================"
    echo "INSTRUCTOR VALIDATION: $block"
    echo "======================================================================"
    echo "RTL:    $rtl"
    echo "Script: $script"
    echo "Log:    $log"
    echo

    if [ ! -f "$rtl" ] || [ ! -f "$script" ]; then
        echo "ERROR: missing final RTL or instructor script."
        failed=$((failed + 1))
        continue
    fi

    # The official run_<module>.sh locates its original instructor TB and
    # sample vectors relative to module_packages/<module>/.
    bash "$script" "$rtl" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}

    if [ "$rc" -eq 0 ] && grep -q "^>>> RESULT: PASS$" "$log"; then
        echo "[${block}] PASS"
    else
        echo "[${block}] FAIL"
        failed=$((failed + 1))
    fi
done

echo
echo "======================================================================"
echo "INSTRUCTOR VALIDATION SUMMARY"
echo "======================================================================"

if [ "$failed" -eq 0 ]; then
    echo "All four final RTL files passed the original instructor test flow."
    exit 0
else
    echo "$failed block(s) failed instructor validation."
    exit 1
fi
