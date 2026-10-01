#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$R/scripts/run_pc_unit.sh"
"$R/scripts/run_branch_unit.sh"
"$R/scripts/run_memory_access.sh"
python3 - "$R" <<'PYIN'
import json,subprocess,sys,pathlib
r=pathlib.Path(sys.argv[1])
m=json.loads((r/'programs/sample/manifest.json').read_text())
for t in m:
    print('PROGRAM',t['name'])
    p=subprocess.run([str(r/'scripts/run_datapath_program.sh'),str(r/t['program']),t['expect'],str(t['max_cycles'])])
    if p.returncode!=0:
        sys.exit(p.returncode)  # forward the program's own output; no Python traceback (would read as an error)
PYIN
