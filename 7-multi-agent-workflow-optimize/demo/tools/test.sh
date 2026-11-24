#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../workspace"
python3 -m unittest discover -s tests -v
