#!/usr/bin/env bash
# run_datapath_all.sh: Run every sample program through the integrated datapath (datapath_tb).
# run_datapath_all.sh: Used as the Debugging Agent's test target for the datapath (all 8 modules together).
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$R" <<'PYIN'
import json,subprocess,sys,pathlib
r=pathlib.Path(sys.argv[1])
m=json.loads((r/'programs/sample/manifest.json').read_text())
for t in m:
    print('PROGRAM',t['name'])
    p=subprocess.run([str(r/'scripts/run_datapath_program.sh'),str(r/t['program']),t['expect'],str(t['max_cycles'])])
    # Exit cleanly on the first failing program, forwarding its own output as the failure signal.
    # Do NOT let Python raise (its traceback contains "error:", which would misclassify a real
    # simulation failure as a compile error).
    if p.returncode!=0:
        sys.exit(p.returncode)
PYIN
