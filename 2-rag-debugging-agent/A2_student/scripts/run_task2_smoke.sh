#!/usr/bin/env bash
# Task 2: execute one complete RAG + iterative-feedback debugging-agent smoke test.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVIDER="${1:-tamu}"
MODEL="${2:-gpt-5.4}"
cd "$ROOT"
mkdir -p logs
python agent/run_debug_agent.py --module pc_unit --arm rag_feedback --provider "$PROVIDER" --model "$MODEL" --log-file logs/pc_unit_smoke.json