# ECEN 689 Assignment 6 - Multi-Agent Hardware Orchestrator

This is a reusable, file-backed Claude Code workflow for RTL generation, self-checking testbench generation, closed-loop repair, verification audit, and ORFS/OpenROAD physical design. The current target is selected by `workspace/target.json`; prompts do not hard-code a module interface.

## Prerequisites

On Olympus, complete the course setup for Claude Code, the TAMU gateway, Icarus Verilog 12, Singularity, and the Assignment 4 ORFS SIF. The activation script prompts for the API token securely and never stores it in this repository.

## Run

```bash
cd /home/grads/n/nithingowtham25/Fall_2026/ecen-689-agentic_hw_dsgn/agentic-riscv-design/6-multi-agent-orchestrator
source scripts/activate_olympus_env.sh
bash scripts/run_preflight.sh
bash run_orchestrator.sh
```

Optional controls:

```bash
bash run_orchestrator.sh --max-repairs 3
bash run_orchestrator.sh --skip-synthesis
```

The terminal prints each stage and sub-stage, status, repair attempt, duration, available usage/cost data, and the final run directory.

## Target configuration

`workspace/target.json` identifies the module name, RTL/TB filenames, testbench top, specification, optional reference, SDC, and ORFS flow variant. To use a different target, add its specification/constraint artifacts and update this configuration; the orchestrator and all specialist prompts remain unchanged.

## Immutable run layout

Every invocation creates a separate directory:

```text
workspace/runs/<run-id>/
  src/                 generated/final RTL
  tb/                  self-checking testbench
  reports/             state, transcripts, usage, simulation and synthesis evidence
  pd/orfs_work/        isolated ORFS work products
```

The original successful run is archived under `workspace/runs/a6_20261122T000411Z/`. New runs never overwrite it.

## Evidence to retain

For each final run, retain `reports/orchestration_state.json`, `reports/token_usage.json`, agent transcripts, simulation summary/log, synthesis summary/log, verification audit, PD notes, final RTL/TB, and ORFS reports. `token_usage.json` aggregates the metadata found in raw Claude CLI transcripts and tolerates custom-model warning text.

## Main source files

- `AGENTS.md` - generic workflow rules and repair policy.
- `sub_agents/` - generic specialist instructions.
- `tools/orchestrate.py` - controller and stage/sub-stage terminal reporting.
- `tools/run_simulation.py` - parameterized Icarus runner.
- `tools/run_synthesis.py` - parameterized isolated ORFS runner.
- `workspace/specs/` - target-specific contracts; these are intentionally not generic prompts.
