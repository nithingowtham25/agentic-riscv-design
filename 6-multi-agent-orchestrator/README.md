# ECEN 689 Assignment 6 Multi Agent Hardware Orchestrator

This project is a reusable Claude Code driven hardware orchestration harness. It coordinates RTL generation, self-checking testbench generation, bounded debug repair, verification expansion, and ORFS/OpenROAD PPA extraction. The current configured target is the Assignment 2 `memory_access` module; the orchestration and specialist prompts are generic and receive target paths at runtime.

## Repository layout

```text
6-multi-agent-orchestrator/
├── AGENTS.md                         master workflow, ownership, state, repair policy
├── README.md                         setup, reproduction, artifact, and packaging guide
├── run_orchestrator.sh               improved timestamped non-overwriting run wrapper
├── scripts/
│   ├── activate_olympus_env.sh       Claude, TAMU gateway, Python, and Icarus activation
│   └── run_preflight.sh              environment and target configuration validation
├── sub_agents/
│   ├── RTL_AGENT.md                  generic RTL specialist policy
│   ├── TB_AGENT.md                   generic self-checking TB specialist policy
│   ├── DEBUG_AGENT.md                generic evidence-based repair policy
│   ├── VERIFY_AGENT.md               generic coverage-audit policy
│   └── PD_AGENT.md                   generic physical-design handoff policy
├── tools/
│   ├── orchestrate.py                versioned closed-loop controller
│   ├── run_simulation.py             parameterized Icarus simulation runner
│   ├── run_synthesis.py              parameterized isolated ORFS runner
│   └── logger.py                     state, transcript, token, cost, and iteration logger
└── workspace/
    ├── target.json                   active target module/spec/TB/PD configuration
    ├── specs/                        target-specific functional specifications
    ├── reference/                    optional prior artifacts for context only
    ├── pd/                           target SDC and static PD inputs
    ├── preflight/                    timestamped environment checks
    └── runs/                         immutable evidence for separate orchestration runs
        └── a6_<timestamp>/
            ├── src/                  generated/final RTL
            ├── tb/                   generated/final self-checking TB
            ├── reports/              state, logs, transcripts, audits, token and PPA summaries
            └── pd/orfs_work/         isolated OpenROAD flow products and reports
```

`workspace/runs/` intentionally retains separate runs so a later invocation never overwrites the evidence of an earlier experiment. The authoritative submission run is `a6_20261123T011937Z`.

## One time Olympus setup

Complete the course setup for Claude Code, the TAMU gateway, Miniforge/Python, Icarus Verilog 12, Singularity, and the Assignment 4 ORFS SIF. Never store a TAMU API key in a script, `.env`, or the repository.

The activation script checks `A6_TOOLS_DIR` for `miniforge3/` and `a6_icarus/`. Its default value is specific to the original author account. **After extracting this ZIP on another account, set it to your own installation before sourcing the script.** For example:

```bash
export A6_TOOLS_DIR="$HOME/.tools/a6"
source scripts/activate_olympus_env.sh
```

Alternatively, edit the default path near the top of `scripts/activate_olympus_env.sh`. The directory must contain:

```text
$A6_TOOLS_DIR/miniforge3/etc/profile.d/conda.sh
$A6_TOOLS_DIR/a6_icarus/bin/iverilog
```

When the script runs, it securely prompts:

```text
Enter TAMU API key:
```

Enter the TAMU gateway key interactively. It is held only in the current shell as `ANTHROPIC_AUTH_TOKEN` and is never written to disk. The configured TAMU Claude model may also be adjusted in the activation script if the recipient's gateway exposes a different model identifier.

### ORFS SIF path

The default project layout expects the image at:

```text
../4-physical-design-agent/lab4-orfs-fall2026-v1.sif
```

If the image is stored elsewhere, update the path consistently in **both** `scripts/run_preflight.sh` and the `A4_SIF` definition near the top of `tools/run_synthesis.py`. Preflight and synthesis must reference the same image location.

## Reproduce a complete run

```bash
cd /path/to/6-multi-agent-orchestrator
export A6_TOOLS_DIR="/path/to/your/a6-tools"
source scripts/activate_olympus_env.sh
bash scripts/run_preflight.sh
bash run_orchestrator.sh
```

`run_orchestrator.sh` was expanded beyond the provided one-line Claude invocation. It creates a unique run ID, saves the terminal log inside that run, invokes the Python controller, and prints stage/sub-stage status, attempts, elapsed time, available token/cost data, result paths, and a final summary. The controller permits up to three RTL repairs after a failed simulation; on a passing simulation Debug performs a no-change audit.

Optional controls:

```bash
bash run_orchestrator.sh --max-repairs 3
bash run_orchestrator.sh --skip-synthesis
```

## Latest run evidence

The submission run is `workspace/runs/a6_20261123T011937Z/`.

| Evidence | Location |
|---|---|
| Final RTL | `src/memory_access.sv` |
| Final self-checking testbench | `tb/tb_memory_access.sv` |
| Terminal execution trace | `reports/terminal_run.log` |
| State transitions and stage status | `reports/orchestration_state.json` |
| Per-agent transcript and metadata | `reports/transcripts/` |
| Token/cost aggregation | `reports/token_usage.json` |
| Final simulation evidence | `reports/sim_summary.json`, `reports/sim_output.log` |
| Debug and verification analysis | `reports/debug_audit.json`, `reports/verification_audit.md` |
| PPA summary and raw flow log | `reports/synth_summary.json`, `reports/synthesis_output.log` |
| ORFS reports | `pd/orfs_work/reports/asap7/memory_access/a6_memory_access/` |
