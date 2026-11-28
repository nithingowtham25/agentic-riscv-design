#!/usr/bin/env bash
set -euo pipefail

# Resolve workspace root relative to this script's location
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running converter from workspace: ${WORKSPACE_DIR}"

python3 "${WORKSPACE_DIR}/src/converter.py" --decimal 10  --out "${WORKSPACE_DIR}/results/decimal.json"
echo "Wrote results/decimal.json"

python3 "${WORKSPACE_DIR}/src/converter.py" --binary 1010 --out "${WORKSPACE_DIR}/results/binary.json"
echo "Wrote results/binary.json"
