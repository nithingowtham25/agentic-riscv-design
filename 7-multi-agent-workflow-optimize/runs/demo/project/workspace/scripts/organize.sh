#!/usr/bin/env bash
set -euo pipefail

# Resolve workspace root relative to this script's location
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Workspace: ${WORKSPACE_DIR}"

# Create required directories
mkdir -p "${WORKSPACE_DIR}/src"
mkdir -p "${WORKSPACE_DIR}/tests"
mkdir -p "${WORKSPACE_DIR}/results"
echo "Directories created: src/ tests/ results/"

# Move inbox/converter.py to src/converter.py if it still exists
if [ -f "${WORKSPACE_DIR}/inbox/converter.py" ]; then
    mv "${WORKSPACE_DIR}/inbox/converter.py" "${WORKSPACE_DIR}/src/converter.py"
    echo "Moved inbox/converter.py -> src/converter.py"
else
    echo "inbox/converter.py not found; skipping move"
fi
