#!/usr/bin/env bash
# Stop on command errors, unset variables, or failures inside pipelines.
set -euo pipefail
# Locate this release even when called from another working directory.
ROOT="$(cd "$(dirname "$0")" && pwd -P)"

# Select a course project. Existing custom directory paths also work.
usage() { echo 'Usage: bash run.sh demo|baseline|revised|PROJECT_DIR [--telemetry on|off] [--out PATH] [--model MODEL]'; }
[[ $# -gt 0 ]] || { usage; exit 2; }
[[ "$1" != --help && "$1" != -h ]] || { usage; exit 0; }
target="$1"; shift
case "$target" in
    demo) project="$ROOT/demo";;
    baseline) project="$ROOT/baseline_framework";;
    revised) project="$ROOT/revised_framework";;
    *) project="$target"
       [[ "$project" == /* ]] || project="$ROOT/$project"
       target="$(basename "$project")";;
esac
# revised_framework starts empty: students add their Task 3 implementation there.
if [[ "$target" == revised && ! -f "$project/run_orchestrator.sh" ]]; then
    echo 'Add your Task 3 agents and run_orchestrator.sh to revised_framework/ first.' >&2
    exit 2
fi
[[ -d "$project" && -f "$project/run_orchestrator.sh" ]] || {
    echo "Project must be a directory containing run_orchestrator.sh: $project" >&2
    exit 2
}
project="$(cd "$project" && pwd -P)"

# Default output is unique per run. The model is passed to the project
# launcher through environment variables; command-line options below override them.
mode=on
out="$ROOT/runs/$target-$(date +%Y%m%d-%H%M%S)-$$"
default_model=sonnet
[[ "$project" != "$ROOT/demo" ]] || default_model=haiku
export AGENT_MODEL="${AGENT_MODEL:-$default_model}"

# Accept only the named options below; unknown options are errors.
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || { usage; exit 2; }
    case "$1" in
        --telemetry) mode="$2";;
        --out) out="$2";;
        --model) AGENT_MODEL="$2";;
        *) usage; exit 2;;
    esac
    shift 2
done
[[ "$mode" == on || "$mode" == off ]] || { usage; exit 2; }
# The Assignment 6 hardware workflows require the Linux course server.
if [[ ( "$project" == "$ROOT/baseline_framework" || "$project" == "$ROOT/revised_framework" ) && "$(uname -s)" != Linux ]]; then
    echo 'Hardware runs require the Linux course server.' >&2; exit 2
fi

# Resolve relative output paths from the caller's directory and refuse overwrites.
[[ "$out" == /* ]] || out="$PWD/$out"
out="$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve())' "$out")"
case "$out/" in "$project/"*)
    echo 'Output must be outside the source project directory.' >&2; exit 2;;
esac
[[ ! -e "$out" ]] || { echo "Output already exists: $out" >&2; exit 2; }
# Give the copied project an absolute specs path; avoid Python cache files.
export PYTHONDONTWRITEBYTECODE=1 COURSE_SPECS_DIR="$ROOT/specs"

# Work on a fresh copy so generated files stay in this run. To change the next
# experiment, edit the source project rather than a previous run's copy.
mkdir -p "$(dirname "$out")"
mkdir "$out"
cp -R "$project" "$out/project"
mkdir "$out/claude"

# Write process status on normal completion or command failure, preserving the
# exit code for the caller. This reports process success, not hardware correctness.
# Telemetry flushing/export is handled separately by telemetry/run.py.
SECONDS=0
finish() {
    status=$?
    trap - EXIT  # Avoid calling finish again when it exits.
    python3 - "$target" "$mode" "$status" "$SECONDS" > "$out/result.json" <<'PYTHON'
import json, sys
status = int(sys.argv[3])
json.dump({"target": sys.argv[1], "telemetry": sys.argv[2], "exit_code": status,
           "status": "process_completed" if status == 0 else "process_failed",
           "wall_time_s": int(sys.argv[4])}, sys.stdout)
print()
PYTHON
    exit "$status"
}
trap finish EXIT
echo "Run directory: $out"

# With telemetry on, start the collector, pass its environment to the project,
# then stop it and export the received data. With telemetry off, run the same
# project with collection disabled. Keep agent stdout/stderr in separate logs.
# The original Assignment 6 script expects the project as its working directory.
(
    cd "$out/project"
    # File descriptor 3 keeps short telemetry progress messages on screen while
    # the agent's full output remains in the run directory.
    TELEMETRY_STATUS_FD=3 python3 "$ROOT/telemetry/run.py" --out "$out/telemetry" --mode "$mode" -- \
        bash "$out/project/run_orchestrator.sh" > "$out/claude/stdout.log" 2> "$out/claude/stderr.log"
) 3>&1
