#!/usr/bin/env bash
# check_setup.sh: Assignment 3 environment preflight. Run from the A3_student package root:
# check_setup.sh:   bash check_setup.sh
# check_setup.sh: Verifies Python, Icarus Verilog (with the SystemVerilog + immediate-assertion features
# check_setup.sh: Assignment 3 uses), that the reference model imports, and that the harness can run your core.
# check_setup.sh: It does NOT check for an LLM API key (that's your responsibility).
set -u
PASS=0; FAIL=0
ok(){ echo "  [ OK ] $1"; PASS=$((PASS+1)); }
bad(){ echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn(){ echo "  [warn] $1"; }
echo "== Assignment 3 setup check =="

# 1) Python
if command -v python >/dev/null 2>&1; then PY=python
elif command -v python3 >/dev/null 2>&1; then PY=python3
else PY=""; fi
if [ -n "$PY" ]; then ok "python found ($($PY --version 2>&1))"; else bad "python / python3 not found"; fi

# 2) Icarus Verilog present
if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
    ok "iverilog + vvp on PATH ($(iverilog -V 2>/dev/null | head -1))"
    HAVE_IV=1
else
    bad "iverilog/vvp not found (install per the Course Setup Guide)"; HAVE_IV=0
fi

# 3) Icarus supports the SystemVerilog features Assignment 3 uses, incl. IMMEDIATE assertions (assert...else).
if [ "$HAVE_IV" = "1" ]; then
    TMP="$(mktemp -d)"
    cat > "$TMP/feat.sv" <<'EOF'
module feat(input logic clk, input logic [31:0] x);
  always @(posedge clk) assert (x < 32'd100) else $display("ASSERT_FAIL demo");
endmodule
module tb; logic clk=0; logic [31:0] x=5; feat d(.*); always #5 clk=~clk;
  initial begin repeat(3) @(posedge clk); $display("PASS"); $finish; end endmodule
EOF
    if iverilog -g2012 -o "$TMP/feat.vvp" "$TMP/feat.sv" >/dev/null 2>&1 \
       && vvp "$TMP/feat.vvp" 2>/dev/null | grep -q '^PASS$'; then
        ok "Icarus compiles -g2012 + immediate SVA assertions (needed for Task 4)"
    else
        bad "Icarus present but the SystemVerilog/assertion feature test failed (need iverilog v11+)"
    fi
    rm -rf "$TMP"
fi

# 4) reference model imports (ISS + encoders)
if [ -n "$PY" ] && "$PY" -c "import sys; sys.path.insert(0,'reference'); import iss, rv32i_isa" 2>/dev/null; then
    ok "reference model imports (iss, rv32i_isa)"
else
    bad "reference/ failed to import (run from the A3_student package root)"
fi

# 5) harness runs end-to-end on the provided skeleton (a tiny program). We only check that the harness
#    COMPILES + EXECUTES the core -- not that the test passes: the shipped skeleton has stub submodules,
#    so it correctly produces the WRONG result until you fill it in. Seeing the "tests pass your core"
#    summary line means the toolchain works.
if [ -n "$PY" ] && [ "$HAVE_IV" = "1" ]; then
    TMP2="$(mktemp -d)"; mkdir -p "$TMP2/tests"
    "$PY" - "$TMP2/tests/smoke.hex" <<'EOF'
import sys
sys.path.insert(0, "reference")
from rv32i_isa import ADDI, LUI, SW
prog = [ADDI(1,0,7), LUI(31,0), ADDI(31,31,0x100), SW(31,1,0)]
open(sys.argv[1], "w").write("".join(f"{w&0xffffffff:08x}\n" for w in prog))
EOF
    if "$PY" harness/run.py --tests "$TMP2/tests" --core core/datapath_pipelined.sv 2>/dev/null \
         | grep -q "tests pass your core"; then
        ok "harness runs end-to-end (compiles + simulates the core)"
    else
        bad "harness/run.py could not run end-to-end (Icarus/harness problem, not your pipeline logic)"
    fi
    rm -rf "$TMP2"
fi

echo
echo "== $PASS passed, $FAIL failed =="
if [ "$FAIL" -eq 0 ]; then
    echo "Environment ready."
    exit 0
else
    echo "Fix the [FAIL] items above (see the Course Setup Guide) and re-run."
    exit 1
fi
