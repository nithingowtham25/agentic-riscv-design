#!/usr/bin/env bash
# check_setup.sh: preflight for Assignment 2 - verifies Python, Icarus (+SV features), the module
# check_setup.sh: run scripts, the RAG index build, the agent imports, and that an LLM API key is visible.
# check_setup.sh: Run from the package root. Does NOT call the LLM API; it only checks the key is set.
set -u

PASS=0; FAIL=0
ok(){ echo "  [ OK ] $1"; PASS=$((PASS+1)); }
bad(){ echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "== Assignment 2 setup check =="

# 1) Python
if command -v python >/dev/null 2>&1; then PY=python; elif command -v python3 >/dev/null 2>&1; then PY=python3; else PY=""; fi
if [ -n "$PY" ]; then ok "Python found ($($PY --version 2>&1))"; else bad "Python not found"; fi

# 2) Icarus Verilog + a SystemVerilog feature compile test
if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
    ok "iverilog + vvp on PATH ($(iverilog -V 2>/dev/null | head -1))"
    TMP="$(mktemp -d)"
    cat > "$TMP/feat.sv" <<'EOF'
module feat_tb; logic [31:0] a=32'h80000000; logic signed [31:0] s; string msg;
initial begin s=$signed(a)>>>1; msg="ok"; if(s===32'hC0000000 && msg=="ok") $display("PASS"); else $display("FAIL"); end
endmodule
EOF
    if iverilog -g2012 -o "$TMP/feat.vvp" "$TMP/feat.sv" >/dev/null 2>&1 && \
       vvp "$TMP/feat.vvp" 2>/dev/null | grep -q '^PASS$'; then
        ok "Icarus handles the required SystemVerilog ( \$signed / >>> / string )"
    else bad "Icarus present but a SystemVerilog feature test failed (need a recent iverilog, v11+)"; fi
    rm -rf "$TMP"
else
    bad "iverilog/vvp not found (install per the handout / Course Setup Guide)"
fi

# 3) the four module run scripts are present
missing=""
for s in run_pc_unit.sh run_branch_unit.sh run_memory_access.sh run_datapath_program.sh; do
    [ -f "scripts/$s" ] || missing="$missing $s"
done
if [ -z "$missing" ]; then ok "all module run scripts present (scripts/)"; else bad "missing run scripts:$missing (run from the package root)"; fi

# 4) module specs present
if [ -f specs/pc_unit_spec.md ] && [ -f specs/branch_unit_spec.md ] && [ -f specs/memory_access_spec.md ] && [ -f specs/datapath_spec.md ]; then
    ok "all four module specs present (specs/)"
else bad "one or more specs/*_spec.md missing"; fi

# 4b) seeded-bug files present (Task 3 repair exercise)
if [ -f bugs/pc_unit_buggy.sv ] && [ -f bugs/branch_unit_buggy.sv ] && [ -f bugs/memory_access_buggy.sv ] && [ -f bugs/datapath_buggy.sv ]; then
    ok "all four seeded-bug files present (bugs/)"
else bad "one or more bugs/*_buggy.sv missing (needed for the Task 3 seeded-bug repair)"; fi

# 4c) sample integration assets present (Task 3/5: datapath + run_all_sample)
int_missing=""
for f in scripts/run_all_sample.sh scripts/run_datapath_all.sh testbench/datapath_tb.sv programs/sample/manifest.json; do
    [ -f "$f" ] || int_missing="$int_missing $f"
done
nprog=$(ls programs/sample/*.hex 2>/dev/null | wc -l | tr -d ' ')
if [ -z "$int_missing" ] && [ "${nprog:-0}" -gt 0 ]; then
    ok "sample integration assets present (run_all_sample.sh, datapath_tb.sv, $nprog program(s))"
else bad "missing integration assets:$int_missing (program hex files found: ${nprog:-0}) - needed for run_all_sample.sh"; fi

# 5) RAG embedding dependencies are importable (the first index build downloads a model; we only
#    check the imports here, not a full build, to keep the preflight fast and offline-friendly).
if [ -n "$PY" ] && "$PY" -c "import sentence_transformers, faiss" 2>/dev/null; then
    ok "RAG embedding dependencies present (sentence-transformers, faiss)"
else bad "RAG dependencies missing - run: pip install -r requirements.txt (or recreate the conda env)"; fi

# 6) agent modules import
if [ -n "$PY" ] && "$PY" -c "import sys; sys.path.insert(0,'.'); sys.path.insert(0,'agent'); import iterative_rtl_agent, tool_feedback, llm_clients" 2>/dev/null; then
    ok "agent modules import (iterative_rtl_agent, tool_feedback, llm_clients)"
else bad "agent modules failed to import (run from the package root)"; fi

# 7) an API key is visible (env or .env) - we do NOT call the API here
if [ -n "$PY" ] && "$PY" -c "import sys; sys.path.insert(0,'agent'); import llm_clients, os; raise SystemExit(0 if (os.getenv('TAMUS_AI_CHAT_API_KEY') or os.getenv('OPENAI_API_KEY')) else 1)" 2>/dev/null; then
    ok "an LLM API key is set (TAMU or OpenAI)"
else bad "no LLM API key found - set TAMUS_AI_CHAT_API_KEY or OPENAI_API_KEY (see the Course Setup Guide)"; fi

echo "== result: $PASS passed, $FAIL failed =="
if [ "$FAIL" -eq 0 ]; then echo "Setup looks good - you can start the assignment."; else echo "Fix the [FAIL] items above, then re-run."; exit 1; fi
