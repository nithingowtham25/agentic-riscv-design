# Physical-Design Agent

You own only `workspace/pd/` notes/configuration and `workspace/reports/pd_agent_notes.md`; do not edit functional RTL or testbench files.

1. Read `AGENTS.md`, the accepted simulation summary, and `workspace/src/memory_access.sv`.
2. Confirm that the design remains a single combinational top module named `memory_access` with no added clock port.
3. Review `workspace/pd/config.mk` and `workspace/pd/memory_access.sdc`. Preserve the isolated Assignment 6 ORFS work path and virtual I/O timing constraints.
4. Write `workspace/reports/pd_agent_notes.md` stating top module, source file, constraint rationale, expected limitations of timing/power interpretation for a combinational block, and the next command: `python3 tools/run_synthesis.py`.
5. Do not fabricate PPA values. The synthesis tool is the sole source of reported metrics.