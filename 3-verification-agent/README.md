# ECEN 689 Assignment 3 - Verification Agent

This directory contains a five-stage pipelined RV32I core, a coverage-driven Verification Agent, generated verification artifacts, and reproducible task runners. The report PDF is submitted separately and must not be added to the submission ZIP. Do not submit `.env` or any API key.

## Folder map

- `core/datapath_pipelined.sv` - completed Task 1 five-stage core. Only its three designated TODO regions were implemented.
- `core/submodules/` - reused `alu`, `regfile`, `extend`, `controller`, `branch_unit`, and `memory_access` modules from Assignments 1 and 2.
- `agent/run_agent.py` - required agent entry point. It accepts the exact required interface and supports TAMU AI Chat.
- `agent/self_mutate.py` - makes disposable buggy copies of the core and confirms the generated suite detects the required bug classes.
- `harness/` and `reference/` - supplied, unmodified simulation and oracle infrastructure.
- `results/tests/*.hex` - generated RV32I test programs.
- `results/assertions.sv` - generated `student_assertions` module.
- `results/coverage.json` - before/after coverage percentages.
- `results/run_records/` - agent transcript, provider/model/token usage, harness outputs, and self-mutation evidence.
- `scripts/` - repeatable commands described below.

## Prerequisites

1. Activate the supplied Assignment 3 environment and work from this directory.
2. Put `TAMUS_AI_CHAT_API_KEY=...` in a local `.env` file. The file is intentionally excluded from submission.
3. Confirm the simulator and Python environment:

```bash
bash check_setup.sh
```

## Terminal-output evidence

Every supplied runner both displays its output and saves the complete terminal transcript in `results/terminal_logs/` as a timestamped `.log` file. Keep these logs for analysis and include them in the ZIP. The agent also writes structured, machine-readable records to `results/run_records/`.

## Reproduce Task 1 - pipelined core

The six earlier-assignment modules are already placed under `core/submodules/`. Run all 13 provided oracle tests:

```bash
bash scripts/run_task1_pipeline.sh
```

Expected result: `13/13 tests pass your core`.

## Reproduce Task 1C - Verification Agent sanity check

This is where the handout's Phase 1C command is executed. It invokes the required agent entry point, creates a few additional RV32I `.hex` programs in `results/tests/`, runs them against `core/`, then explicitly replays the handout's harness command:

```bash
bash scripts/run_task1_agent_sanity.sh tamu gpt-5.4
```

The generated programs are in `results/tests/`; its terminal transcript is in `results/terminal_logs/task1_agent_sanity_<timestamp>.log`.

## Reproduce Tasks 2, 3, and 4 - Verification Agent

Run the agent with TAMU AI Chat. The same model and generation settings should be retained for all reported runs.

```bash
bash scripts/run_tasks2to4_agent.sh tamu gpt-5.4 2
```

Equivalent required entry point:

```bash
python agent/run_agent.py --provider tamu --out results --core core --max-calls 2 --model gpt-5.4
```

The agent respects `--max-calls`: it never makes more requests than this value. It records every request/response, provider, model, and token-use object in `results/run_records/`. It emits instruction-aware RV32I `.hex` programs, accepts only simulator/oracle results as evidence, measures coverage before and after adding the full targeted suite, and creates the assertion module from the required invariants.

To validate the Task 2 suite against disposable bug injections:

```bash
bash scripts/run_task2_self_mutation.sh
```

This writes `results/run_records/self_mutation.json` and checks forwarding, x0 forwarding, load-use stall, redirect/flush, and redirect-target mutations. It never edits `core/`.

To confirm assertions are silent on the correct core (Task 4):

```bash
bash scripts/run_final_check.sh
```

Expected result: all generated tests pass and the assertion check reports that no `ASSERT_FAIL` line fired.

## Submission checklist

Create `<UIN>_A3.zip` from this folder after removing `.env` and any temporary `results/_core_under_test/` or `results/self_mutation/*/core/` staging copies if a small archive is desired. Retain required `results/tests/`, `results/assertions.sv`, `results/coverage.json`, and `results/run_records/`. Submit `<UIN>_A3_Report.pdf` separately; never place the report PDF in the ZIP.