#!/bin/bash
#SBATCH --job-name=a5_data
#SBATCH --partition=medium
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --output=logs/data_%j.out
#SBATCH --error=logs/data_%j.err
# Add --account=YOUR_GRACE_ALLOCATION only if your allocation requires it.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source .venv/bin/activate
export HF_HOME="${HF_HOME:-$SCRATCH/a5_hf_cache}"
export TOKENIZERS_PARALLELISM=false
: "${MAX_TOKENS:?Submit with --export=ALL,MAX_TOKENS=2048 (or your chosen limit)}"
: "${DATA_REVISION:?Submit with an immutable VeriThoughts DATA_REVISION}"
python -u student_code/prepare_data.py \
  --count "${DATA_COUNT:-2500}" \
  --response-format "${RESPONSE_FORMAT:-reasoned}" \
  --max-tokens "$MAX_TOKENS" --seed "${DATA_SEED:-42}" \
  --revision "$DATA_REVISION"
