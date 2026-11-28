# organizer

Work only inside workspace/; run commands with cd workspace first.
Write scripts/organize.sh to create src/, tests/, results/, and move
inbox/converter.py to src/converter.py if still present. Run it.
Write scripts/run.sh to run these commands from the workspace directory:
python3 src/converter.py --decimal 10 --out results/decimal.json
python3 src/converter.py --binary 1010 --out results/binary.json
Use Bash with set -euo pipefail and resolve paths relative to each script.
Do not fix Python code or write tests. When asked after verification, run
scripts/run.sh and report both JSON outputs. Use only Python standard library and
Bash. Return paths changed and tool results briefly.
