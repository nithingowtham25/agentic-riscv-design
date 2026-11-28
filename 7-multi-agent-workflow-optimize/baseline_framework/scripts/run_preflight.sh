#!/usr/bin/env bash
# Record the Assignment 6 runtime prerequisites before a full orchestration run.
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$ROOT"
source scripts/activate_olympus_env.sh
mkdir -p workspace/preflight
log="workspace/preflight/preflight_$(date -u +%Y%m%dT%H%M%SZ).log"
{
  echo "=== Assignment 6 preflight ==="
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "Repository: $ROOT"
  echo "Icarus: $(iverilog -V 2>&1 | head -1)"
  echo "VVP: $(vvp -V 2>&1 | head -1)"
  echo "Claude: $(claude --version | head -1)"
  command -v singularity
  singularity --version
  # A7_ORFS_SIF is an Assignment 7 runtime configuration override.  It lets
  # the fresh per-run project copy use a shared ORFS image without altering
  # the baseline agent prompts, roles, or orchestration policy.
  ORFS_SIF="${A7_ORFS_SIF:-$ROOT/../4-physical-design-agent/lab4-orfs-fall2026-v1.sif}"
  test -f "$ORFS_SIF"
  echo "Assignment 4 ORFS SIF: PASS ($ORFS_SIF)"
  test -f "workspace/target.json"
  python3 -c 'import json; p=json.load(open("workspace/target.json")); print("Target:", p["module_name"]); assert p["spec_path"]'
  echo "Target configuration: PASS"
} 2>&1 | tee "$log"
echo "Preflight log: $log"
