# ECEN 689 Assignment 3 Verification Agent

This directory is the complete reproducible submission package for Assignment 3. It contains the completed five-stage RV32I processor, six reused modules from Assignments 1 and 2, a TAMU-compatible Verification Agent, generated tests and assertions, coverage and self-mutation evidence, and terminal logs.

Before creating `<UIN>_A3.zip`, remove `.env` and move `337001954_A3_Report.docx` out of this directory. Convert that Word file to `337001954_A3_Report.pdf` and submit the PDF separately. Do not include either `.env` or the report file in the ZIP.

## Submission contents

```text
3-verification-agent/
├── README.md                         reproduction and submission guide
├── core/
│   ├── datapath_pipelined.sv         completed five-stage RV32I pipeline
│   └── submodules/                   reused A1/A2 alu, regfile, extend, controller,
│                                     branch_unit, and memory_access modules
├── agent/
│   ├── run_agent.py                  required Verification Agent entry point
│   ├── self_mutate.py                Task 2 copied-core mutation validation
│   └── tamu_ai_chat_client.py        TAMU AI Chat client used by the agent
├── tamu_ai_chat/                     package-form TAMU client fallback
├── harness/                          local tools (run, don't edit)
│   ├── run.py                            runs your tests/assertions on your core; reports coverage
│   ├── task1_tests/*.hex                 provided correctness tests for Task 1 (your core must pass all)
│   ├── assertions_template.sv            starter for your assertions (copy to results/assertions.sv)
│   ├── core_tb.sv                        testbench: runs a program on a core vs the reference model
│   ├── core_tb_cov.sv                    testbench with coverage instrumentation
│   └── core_tb_assert.sv                 testbench that binds your assertions into the core
├── reference/                        supplied RV32I instruction-set simulator and encoders
├── docs/
│   ├── pipeline_diagram.md           the 5 stages, registers, and where the 3 TODOs sit
│   ├── forwarding_truth_table.md     spec for TODO 1 (forwarding unit)
│   ├── hazard_unit_spec.md           spec for TODO 2 and TODO 3 (load-use stall, redirect/flush)
│   ├── coverage_metric.md            the 21 coverage bins your tests are scored on
│   └── required_invariants.md        the invariants your assertions must formalize
├── scripts/
│   ├── run_task1_pipeline.sh         Task 1 supplied regression
│   ├── run_task1_agent_sanity.sh     Task 1C agent sanity run
│   ├── run_tasks2to4_agent.sh        Tasks 2-4 agent run
│   ├── run_task2_self_mutation.sh    Task 2 self-mutation validation
│   └── run_final_check.sh            final correct-core suite/assertion replay
├── results/
│   ├── tests/*.hex                   six generated RV32I test programs (submit)
│   ├── assertions.sv                 generated student_assertions module (submit)
│   ├── coverage.json                 exact Task 3 before/after coverage result (submit)
│   ├── run_records/                  JSON records: agent/provider/token and mutation evidence (submit)
│   ├── terminal_logs/                timestamped transcripts from every runner (submit)
│   ├── _before_tests/                initial two-program coverage seed workspace (disposable)
│   ├── _core_under_test/             staged copy of selected --core target for harness execution (disposable)
│   └── self_mutation/                copied buggy cores and their private harness workspaces (disposable)
├── analysis/                         report-ready Task 1 and Tasks 2-4 analyses
├── check_setup.sh                    environment preflight
├── environment.yml                   supplied environment definition
└── env.example                       secret-free environment variable example
```

The agent creates `results/_before_tests/`, `results/_core_under_test/`, and `results/self_mutation/` as disposable workspaces. The permanent evidence is kept in `results/tests/`, `results/assertions.sv`, `results/coverage.json`, `results/run_records/`, and `results/terminal_logs/`.

## Prerequisites

1. Activate the Assignment 3 environment.
2. Create a private `.env` file in the package root containing:

```text
TAMUS_AI_CHAT_API_KEY=your_key_here
```

3. Verify the simulator and Python environment:

```bash
bash check_setup.sh
```

The `.env` file is secret material. It must never be committed or submitted.

## Reproduce the complete assignment

Run these commands from the package root in order. Each script prints live output and also saves a complete timestamped transcript under `results/terminal_logs/`.

### 1. Task 1 pipeline regression

```bash
bash scripts/run_task1_pipeline.sh
```

Expected result: all 13 supplied programs pass. The supplied suite reaches 20/21 bins; AUIPC is the only omitted instruction class.

### 2. Task 1C agent sanity run

```bash
bash scripts/run_task1_agent_sanity.sh tamu gpt-5.4
```

This invokes the required agent interface, writes generated `.hex` programs to `results/tests/`, and replays them with the supplied harness. Expected result: 6/6 generated tests pass and coverage reaches 21/21 bins.

### 3. Tasks 2, 3, and 4 agent run

```bash
bash scripts/run_tasks2to4_agent.sh tamu gpt-5.4 2
```

Equivalent required command:

```bash
python agent/run_agent.py --provider tamu --out results --core core --max-calls 2 --model gpt-5.4
```

The agent never exceeds `--max-calls`. It records the provider, model, token usage, prompts, model response, harness output, coverage, and assertion result in `results/run_records/agent_run.json` and `results/run_records/llm_call_*.json`.

### 4. Task 2 self-mutation validation

```bash
bash scripts/run_task2_self_mutation.sh
```

The script copies the core and injects forwarding, x0, load-use, redirect/flush, and target-address faults. It then executes the unchanged generated suite on each copy. The expected result is `DETECTED` for every mutation. The original `core/`, generated tests, coverage result, and assertions are never modified. Permanent evidence is saved to `results/run_records/self_mutation.json`.

### 5. Final correct-core check

```bash
bash scripts/run_final_check.sh
```

Expected result: 6/6 generated tests pass, coverage remains 21/21 bins, and `results/assertions.sv` produces no `ASSERT_FAIL` line on the correct core.

## Observed completed results

| Evidence | Observed result |
|---|---|
| Task 1 supplied regression | 13/13 pass; 20/21 coverage bins |
| Final generated suite | 6/6 pass; 21/21 coverage bins (100%) |
| Task 3 coverage file | `{"before": 62, "after": 100}` |
| Task 2 self-mutation | all five required bug classes detected |
| Task 4 assertion replay | no false positives on the correct core |
| Agent provider | TAMU AI Chat, `gpt-5.4` |