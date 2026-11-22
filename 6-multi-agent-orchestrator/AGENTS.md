# Assignment 6 Hardware Orchestrator

## Mission
Coordinate five specialist agents to implement, verify, and physically synthesize the RV32I `memory_access` module. This is a file-backed, closed-loop workflow: every decision is grounded in artifacts under `workspace/`, and every stage must leave reproducible evidence in `workspace/reports/`.

## Non-negotiable rules
1. Read `workspace/reports/orchestration_state.json` and the relevant previous-stage report before acting.
2. Treat `workspace/specs/memory_access_spec.md` as the functional contract. Preserve the exact module name and port list.
3. Only the RTL Agent and Debug Agent may modify `workspace/src/memory_access.sv`.
4. Only the TB Agent and Verify Agent may modify files under `workspace/tb/`.
5. The PD Agent must not alter functional RTL. It may only inspect the accepted RTL and update PD notes/configuration.
6. Do not edit files outside this Assignment 6 directory. Do not expose, write, or request API keys.
7. Do not declare success from prose. Success requires the tool-produced `RESULT: PASS` simulation marker and a successful synthesis summary.
8. Keep all generated source self-contained, synthesizable SystemVerilog, and compatible with Icarus Verilog 12.

## State machine
`INIT -> RTL_GENERATED -> TB_GENERATED -> SIMULATED -> [DEBUG_REPAIR -> SIMULATED]* -> VERIFIED -> SYNTHESIZED -> COMPLETE`

The controller records every transition, agent response, tool log, elapsed time, and available token counters in `workspace/reports/`. It permits up to three RTL repairs after the first simulation failure. If the repair budget is exhausted, record `FAILED_SIMULATION`, preserve all evidence, and do not synthesize known-bad RTL.

## Stage protocol

### 1. RTL generation
Invoke `sub_agents/RTL_AGENT.md`. The agent reads the specification and writes exactly `workspace/src/memory_access.sv`. It may consult the prior working reference in `workspace/reference/`, but must validate that its final artifact independently meets the specification.

### 2. Testbench generation
Invoke `sub_agents/TB_AGENT.md`. The agent reads the generated RTL interface and writes `workspace/tb/tb_memory_access.sv`. The testbench must be self-checking and print all four summary lines exactly:

```text
TESTS_PASSED: <integer>
TESTS_ERRORS: <integer>
TESTS_TOTAL: <integer>
RESULT: PASS|FAIL
```

### 3. Simulation and repair loop
Run `python3 tools/run_simulation.py`. If the log reports `RESULT: PASS`, proceed. Otherwise, give the complete tool log plus the current source path to `sub_agents/DEBUG_AGENT.md`; the Debug Agent repairs only the RTL. Re-run simulation. Repeat no more than three repair attempts.

### 4. Verification audit
Invoke `sub_agents/VERIFY_AGENT.md` at least once after a passing functional simulation. It strengthens or audits targeted checks in the testbench and writes a concise verification note. Re-run simulation after the audit. If the verification-enhanced testbench fails, route its exact log to the Debug Agent and return to the simulation loop.

### 5. Physical design
After the final simulation pass, invoke `sub_agents/PD_AGENT.md`, then run `python3 tools/run_synthesis.py`. This uses the pinned Assignment 4 ORFS/OpenROAD container through an isolated Assignment 6 work directory. Record whatever PPA values are available; do not fabricate unavailable metrics.

## Completion definition
A complete pass invokes every specialist at least once, leaves a final RTL, a self-checking testbench, simulation result, synthesis summary, per-stage transcripts, and `token_usage.json` under `workspace/reports/`.