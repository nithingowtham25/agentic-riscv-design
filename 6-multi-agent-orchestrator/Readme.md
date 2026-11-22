# ECEN 689 Assignment 6 - Multi-Agent Hardware Orchestrator

This project implements a file-backed, Claude Code-driven orchestration workflow for the Assignment 2 `memory_access` module. It coordinates RTL generation, self-checking testbench generation, closed-loop debugging, verification audit, and ORFS/OpenROAD physical design.

## One-time Olympus setup
Complete the Claude Code and Icarus 12 installation described in the course setup guide. The coursework-local tools are activated by the script below; the TAMU token is prompted securely and is never stored in this repository.

## Run a complete pass

```bash
cd /home/grads/n/nithingowtham25/Fall_2026/ecen-689-agentic_hw_dsgn/agentic-riscv-design/6-multi-agent-orchestrator
source scripts/activate_olympus_env.sh
bash scripts/run_preflight.sh
bash run_orchestrator.sh
```

The preflight records the Claude, Icarus, Singularity, Assignment 4 SIF, and specification checks under `workspace/reports/`. The orchestration wrapper then sources `scripts/activate_olympus_env.sh`, which prepares Icarus, Claude Code, the TAMU gateway, and the selected Sonnet model. It then invokes every sub-agent and tool in the defined order.

To execute a specific tool during debugging:

```bash
source scripts/activate_olympus_env.sh
python3 tools/run_simulation.py
python3 tools/run_synthesis.py
```

## Important directories

- `AGENTS.md` - master workflow, artifacts, state transitions, and repair policy.
- `sub_agents/` - specialist prompts for RTL, testbench, debug, verification, and physical design.
- `tools/` - orchestrator, simulation, synthesis, and structured logging utilities.
- `workspace/specs/` - Assignment 2 functional contract.
- `workspace/reference/` - prior known-good Assignment 2 reference used only as context.
- `workspace/src/` - generated/final RTL.
- `workspace/tb/` - generated/final self-checking testbench and verification artifacts.
- `workspace/reports/` - immutable run evidence: terminal log, transcripts, state, token/call accounting, simulation log, and PPA summary.
- `workspace/pd/` - isolated ORFS configuration and work area.

## Outputs to retain for the report

The final submission must retain `AGENTS.md`, every `sub_agents/*.md` prompt, all `tools/*.py`, and the complete `workspace/reports/` evidence. The report should cite `token_usage.json`, `orchestration_state.json`, `sim_output.log`, `sim_summary.json`, `synth_summary.json`, and the stage transcripts.

## Notes

- The controller permits three RTL repairs after an initial failing simulation.
- A synthesis failure is logged honestly; it never overwrites a passing simulation result.
- The `memory_access` module is combinational. The ORFS constraint file therefore uses a virtual I/O clock rather than adding a nonexistent RTL clock port.