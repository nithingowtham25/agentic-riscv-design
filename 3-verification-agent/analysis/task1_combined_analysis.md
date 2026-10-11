# Task 1 - Pipelined Core and Verification-Agent Sanity Analysis

## Scope and evidence

This analysis combines the provided Task 1 pipeline regression and the Task 1C Verification Agent sanity run. Primary evidence is retained in `results/terminal_logs/`, while the structured agent record is `results/run_records/agent_run.json`.

## Task 1A/B: Five-stage pipeline implementation and supplied regression

The three permitted hazard-control regions in `core/datapath_pipelined.sv` were completed as follows:

- The forwarding unit selects the freshest matching producer, preferring the Memory stage over Writeback and never forwarding a value into x0.
- Load-use detection stalls Fetch and Decode when a load in Execute writes a nonzero destination used by the Decode instruction; Execute is flushed to insert one bubble.
- Redirect logic uses the Execute-stage branch/jump decision, redirects Fetch to the computed target, and flushes the two younger wrong-path instructions.

The six reused submodules (`alu`, `regfile`, `extend`, `controller`, `branch_unit`, and `memory_access`) were installed in `core/submodules/` without interface changes.

The supplied regression completed with **13/13 programs passing**. It exercised ALU forwarding, chains of dependencies, load-use handling, byte-load sign extension, taken and untaken branches, JAL/JALR behavior including JALR bit-zero masking, logic/shifts, memory-to-Execute forwarding, and x0 hardwiring. Its measured coverage was **20/21 bins (95%)**, with only `OP_AUIPC` absent. This was a coverage gap in the provided tests, not a functional failure.

## Task 1C: Verification Agent sanity run

The agent emitted six additional RV32I programs under `results/tests/`:

| Program | Primary behavior exercised |
|---|---|
| `forwarding.hex` | Execute/Memory and Writeback dependency forwarding |
| `load_use_and_memory.hex` | Load-use stall plus byte store/load behavior |
| `x0_integrity.hex` | x0 write suppression and zero-valued reads |
| `branch_flush.hex` | Taken and untaken branch paths and wrong-path flush |
| `jumps.hex` | JAL link writeback and odd-target JALR masking |
| `instruction_mix.hex` | LUI, AUIPC, immediate ALU operations, and ordinary execution |

The agent first ran a small initial subset and measured **13/21 bins (62%)**. That run missed `OP_AUIPC`, `OP_JAL`, `OP_JALR`, `OP_LOAD`, `OP_LUI`, `jal`, `jalr`, and `load_use_stall`. It then ran the full generated suite. All six programs passed against the reference ISS, and coverage increased to **21/21 bins (100%)**. In particular, `instruction_mix.hex` supplied the previously missing AUIPC behavior.

The generated immediate assertions were also compiled and run with the six passing programs. They remained silent, so no false positive was observed on the correct core. The assertions check Decode-stage x0 reads, prohibit forwarding into x0, and validate Memory/Writeback forwarding select legality for both Execute operands.

## Result-directory review

The required artifacts are present and correctly located:

- `results/tests/*.hex` - generated test suite.
- `results/assertions.sv` - required `student_assertions` module.
- `results/coverage.json` - exact before/after form: `{"before": 62, "after": 100}`.
- `results/run_records/agent_run.json` - structured harness outputs, coverage, provider/model settings, and LLM-call record.
- `results/terminal_logs/` - terminal transcripts for both Task 1 runs.

The `_before_tests/` and `_core_under_test/` directories are disposable working copies used to measure initial coverage and stage an arbitrary `--core` target. They are intentionally ignored by Git and may be excluded from the final ZIP. They are not required submission evidence.

## Verification-Agent provider evidence

The clean Task 1C run used the required **TAMU AI Chat** provider with model **gpt-5.4** and a fixed maximum of one LLM call. The agent used exactly **1/1** permitted calls. The provider reported **78 prompt tokens, 517 completion tokens, and 595 total tokens**.

The model received the initial coverage result (13/21) and proposed targeted scenarios for both forwarding sources, x0 write/read corner cases, rs1/rs2 load-use dependencies, wrong-path side effects after branch/JAL/JALR redirects, JALR alignment, and branch-target behavior. The agent then emitted valid instruction-encoded `.hex` programs, and the reference ISS plus simulator—not the model response—served as the acceptance authority. The six-program full suite passed and reached 21/21 bins.

This provides reproducible evidence that the framework supports the required provider, obeys the call budget, records model/token metadata, and uses coverage feedback to guide test-suite expansion.

## Final Task 1 conclusion

Task 1 is complete. The five-stage core passes all 13 supplied programs, and the Verification Agent sanity suite adds six passing programs that raise measured coverage from 62% to 100%. The generated assertions are silent on the verified correct core. The relevant evidence is retained in `results/terminal_logs/task1_pipeline_20261010_230230.log`, `results/terminal_logs/task1_agent_sanity_20261011_003207.log`, `results/coverage.json`, and `results/run_records/`.