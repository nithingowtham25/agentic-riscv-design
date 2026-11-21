#!/bin/bash
#SBATCH --job-name=a5_sft
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=20:00:00
#SBATCH --output=logs/sft_%j.out
#SBATCH --error=logs/sft_%j.err
# Add --account=YOUR_GRACE_ALLOCATION only if your allocation requires it.
# Before submitting: check myproject -l and estimate SUs (maxconfig -h).
# Reserve enough GPU budget for a full AFTER evaluation; do not train it away.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source .venv/bin/activate
export HF_HOME="${HF_HOME:-$SCRATCH/a5_hf_cache}"
export TOKENIZERS_PARALLELISM=false
nvidia-smi
python -u student_code/train_sft.py
