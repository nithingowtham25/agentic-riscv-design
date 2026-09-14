#!/usr/bin/env bash

set -u

# This script is located directly inside 1_code/.
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$CODE_DIR" || exit 1

MODEL="gpt-5.4"
PROVIDER="tamu"

BLOCKS=("alu" "regfile" "extend" "controller")
STYLES=("direct" "rules_constraints" "design_planning")

echo "============================================================"
echo "ECEN 689 Assignment 1 - Full Experiment Run"
echo "============================================================"
echo "Working directory : $CODE_DIR"
echo "Model             : $MODEL"
echo "Provider          : $PROVIDER"
echo "Total experiments : 24"
echo "============================================================"

for BLOCK in "${BLOCKS[@]}"; do
    SPEC="specs/${BLOCK}.yaml"

    for STYLE in "${STYLES[@]}"; do
        for RUN in 1 2; do

            OUT_DIR="results/${BLOCK}/${STYLE}/run${RUN}"

            echo
            echo "------------------------------------------------------------"
            echo "Block        : ${BLOCK}"
            echo "Prompt style : ${STYLE}"
            echo "Run          : ${RUN}"
            echo "Output dir   : ${OUT_DIR}"
            echo "------------------------------------------------------------"

            python student_code/lab1.py \
                --spec "$SPEC" \
                --out-dir "$OUT_DIR" \
                --provider "$PROVIDER" \
                --model "$MODEL" \
                --prompt-style "$STYLE"

            STATUS=$?

            if [ $STATUS -eq 0 ]; then
                echo "[PASS] ${BLOCK} / ${STYLE} / run${RUN}"
            else
                echo "[FAIL] ${BLOCK} / ${STYLE} / run${RUN}"
                echo "Continuing to the next experiment..."
            fi

        done
    done
done

echo
echo "============================================================"
echo "All 24 experiments have been executed."
echo "Results are available under:"
echo "  $CODE_DIR/results/"
echo "============================================================"