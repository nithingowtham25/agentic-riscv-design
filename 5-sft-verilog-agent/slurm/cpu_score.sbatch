#!/bin/bash
#SBATCH --job-name=a5_score
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/score_%j.out
#SBATCH --error=logs/score_%j.err
# Add --account=YOUR_GRACE_ALLOCATION only if your allocation requires it.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source .venv/bin/activate
export PATH="${IVERILOG_BIN:+$IVERILOG_BIN:}$PATH"
: "${STAGE:?Submit with --export=ALL,STAGE=before or after}"
python -u student_code/score_v2.py --stage "$STAGE" --jobs 4
