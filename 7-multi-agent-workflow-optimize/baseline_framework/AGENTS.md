# Assignment 6 Hardware Orchestrator

## Mission

Coordinate reusable RTL, testbench, debug, verification, and physical-design specialists for a configured HDL target. The controller supplies `RUN_DIR`, `RTL_PATH`, `TB_PATH`, `MODULE_NAME`, `SPEC_PATH`, and PD settings in every prompt. `workspace/target.json` selects the current target; specialist prompts must not assume a particular module name or interface.

## Rules

1. Read this file, the stage prompt, the supplied runtime paths, and prior evidence before acting.
2. The specification at `SPEC_PATH` is authoritative. Preserve the exact configured module name and interface.
3. RTL and Debug may edit only `RTL_PATH`. TB and Verify may edit only `TB_PATH` plus their supplied audit report. PD must not edit functional RTL/TB.
4. Never edit another run directory. Never expose API keys or modify files outside this Assignment 6 repository.
5. Use synthesizable, self-contained SystemVerilog compatible with Icarus Verilog 12 unless the target contract says otherwise.
6. Tool evidence, not prose, determines pass/fail. A valid simulation requires `RESULT: PASS`; PD metrics come only from ORFS reports.
7. Preserve compatibility with the standard testbench summary lines: `TESTS_PASSED`, `TESTS_ERRORS`, `TESTS_TOTAL`, and conditional `RESULT: PASS|FAIL`.

## State machine and repair policy

`INIT -> RTL -> TB -> SIMULATE -> [DEBUG_REPAIR -> SIMULATE]* -> VERIFY -> SIMULATE -> PD -> SYNTHESIZE -> COMPLETE`

The controller permits at most three RTL repair attempts after functional failure. On a passing simulation, Debug performs a no-change audit. A failed repair budget stops synthesis and preserves the complete run record.

## Run evidence

Each invocation writes only below `workspace/runs/<run-id>/`: generated RTL/TB, agent transcripts, tool logs, state transitions, usage/cost totals, audits, and isolated ORFS work. Existing runs are immutable. The controller records sub-stage progress, attempts, duration, return codes, and transcript-derived Claude usage.

## Completion

A complete pass invokes all five specialists, preserves final RTL and self-checking TB, passes final simulation, produces a synthesis summary when synthesis is requested, and retains every transcript/log in its run directory.
