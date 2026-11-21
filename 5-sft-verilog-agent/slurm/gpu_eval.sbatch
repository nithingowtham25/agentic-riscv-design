#!/bin/bash
#SBATCH --job-name=a5_eval
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=08:00:00
#SBATCH --output=logs/eval_%j.out
#SBATCH --error=logs/eval_%j.err
# Add --account=YOUR_GRACE_ALLOCATION only if your allocation requires it.
# Before submitting: check myproject -l and estimate SUs (maxconfig -h).
# Reserve enough GPU budget for a full AFTER evaluation; do not train it away.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source .venv/bin/activate
export HF_HOME="${HF_HOME:-$SCRATCH/a5_hf_cache}"
export TOKENIZERS_PARALLELISM=false
nvidia-smi
: "${STAGE:?Submit with --export=ALL,STAGE=before or after}"
if [[ "$STAGE" == before ]]; then
    python -u student_code/evaluate_model.py --out output/before --max-new-tokens 2048
elif [[ "$STAGE" == after ]]; then
    python -u student_code/evaluate_model.py --out output/after \
       --adapter output/sft_run/adapter --max-new-tokens 2048
else
    echo "STAGE must be before or after" >&2; exit 1
fi
