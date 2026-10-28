# ECEN 689 Assignment 4 Physical Design Agent

This package contains the physical-design agent, the verified five-stage RV32I processor from Assignment 3, the supplied OpenROAD-flow-scripts (ORFS) helpers and templates, and the recorded baseline and optimization trials. The agent keeps the processor RTL and timing constraints fixed while proposing synthesis and place-and-route settings using TAMU AI Chat.

The assignment handout and Course Setup Guide are the authorities for requirements and cluster setup. The implementation, run commands, and evidence locations are summarized below.

## Folder structure

```text
4-physical-design-agent/
├── README.md                        this reproduction and submission guide
├── check_environment.sh             provided environment preflight
├── run_lab.sh                       provided Singularity agent launcher
├── env.example                      example variable name; no credentials
├── .env                             local secret file, if present; never submit
├── lab4-orfs-fall2026-v1.sif       course image, if installed locally
├── container/                       provided image and runtime helpers
│   ├── stack.env                    pinned image and ORFS versions
│   ├── pull_sif.sh                  image setup and verification
│   ├── runtime_checks.sh            Singularity helper functions
│   └── local_sif.sha256             local image-verification record, if present
├── core/                            fixed, verified Assignment 3 RTL
│   ├── datapath_pipelined.sv        processor top, clock port clk
│   └── submodules/                  alu, regfile, extend, controller,
│                                    branch_unit and memory_access
├── student_code/
│   ├── run_agent.py                 evaluator, metrics, TAMU client and search
│   ├── config.py                    provided paths and fixed timing constants
│   ├── search_space.py              allowed values and baseline parameters
│   ├── tool_runner.py               provided ORFS wrappers and artifact checks
│   └── io_utils.py                  provided text and JSON helpers
├── template/                        provided per-trial configuration templates
│   ├── config_template.mk
│   └── constraint_template.sdc
├── tests/test_infrastructure.py     supplied helper smoke tests
├── scripts/
│   ├── run_preflight.sh             environment check with terminal logging
│   └── run_experiment.sh            required agent launcher with terminal logging
├── output/                          graded evidence from the selected run
│   ├── baseline/                    baseline configuration, metrics and logs
│   ├── trial_001/ ... trial_005/    prompt, response and result for each attempt
│   ├── summary.json                 baseline, best result and stopping reason
│   └── terminal_logs/               timestamped preflight and experiment logs
├── orfs_work/                       ORFS work and generated design artifacts
├── old_output/                     prior run evidence, if archived here
├── old_orfs_work/                  prior ORFS workspace, if archived here
├── .sing_cache/ and .sing_tmp/     local Singularity cache/scratch, if present
└── 337001954_A4_Report.docx        editable report, if kept locally
```

The actual number of trial directories depends on the proposal limit and stopping policy. The report is submitted separately as a PDF. Cache, scratch, image, archived-run and Word-report files shown above may be moved outside the submission folder as appropriate; preserve all required current `output/` evidence.

## Prerequisites

1. Follow the Course Setup Guide for Olympus, Grace, or Faster, including the appropriate compute allocation, Singularity, network access, and course image. Use the supplied image tools if setup is needed.
2. Enter the package root in a cluster shell and activate the prepared course environment. Do not alter the verified RTL or fixed clock and I/O delay across experiments.
3. Configure `TAMUS_AI_CHAT_API_KEY` privately in a package-root `.env` file or export it in your shell. `env.example` shows the variable name. Never submit or commit the key or `.env`.
4. Use the same provider, model, and generation settings for reported experiments. The runs recorded here use TAMU AI Chat and `gpt-5.4`; temperature was left at the provider default.

## Reproduce the workflow

Run these commands from the package root. The wrappers save timestamped terminal output in `output/terminal_logs/` and return the underlying command's exit status.

### 1. Check the environment

```bash
bash scripts/run_preflight.sh
```

This calls the provided `check_environment.sh`, verifies the image and tools, runs the supplied infrastructure checks, and tests TAMU API access. Proceed after `Infrastructure: PASS`, `TAMU API access: PASS`, and `Environment check: PASS`. On Olympus the optional WebProxy module may be unavailable; the completed runs showed that this message did not prevent the checks or experiments. Investigate any actual failing check rather than relying on the module message alone.

### 2. Run the baseline and optimization loop

```bash
bash scripts/run_experiment.sh --provider tamu --trials 5 --model gpt-5.4
```

The wrapper invokes the provided launcher with the same arguments. The assignment's required interface is therefore also available directly:

```bash
bash run_lab.sh --provider tamu --trials 5 --model gpt-5.4
```

The direct command does not use the wrapper's terminal-log capture. Always launch through `run_lab.sh` rather than executing the agent outside the course container. `--trials` must be an integer of at least 1; it limits proposal requests, not the baseline. The default model when omitted is the provided `gpt-5.4-mini`. Use the explicit `gpt-5.4` command above to match the recorded experiments.

The baseline runs first. For each proposal, the agent saves the prompt and response, validates the parameter set, runs synthesis and place-and-route for an accepted new configuration, and records the measured result or failure. Console messages show the major stages; the supplied tool wrapper saves detailed tool output after each tool command finishes. A physical-design run may take considerable time.

### 3. Inspect results and supporting evidence

| Location | Contents |
|---|---|
| `output/baseline/result.json` | Baseline parameters, metrics, units and score |
| `output/baseline/` | Baseline config, constraints, synthesis/PnR logs, metadata and reports |
| `output/trial_*/result.json` | Proposal, validation/tool status, response, metrics, score and provider usage |
| `output/trial_*/prompt.txt` and `response.txt` | Prompt and response for a successful model request |
| `output/trial_*/` | Trial configs, logs, reports and metadata when available |
| `output/summary.json` | Baseline-versus-best comparison, best parameters, attempt count and stop reason |
| `output/terminal_logs/` | Timestamped terminal output from the wrapper scripts |
| `orfs_work/` | Detailed ORFS working files and generated design artifacts |

Rejected proposals and tool failures have records but may not have measurements or tool artifacts. If a request fails before the model returns a response, the response is unavailable. Check the recorded reason and relevant logs before retrying.

### 4. Preserve evidence before another run

The agent refuses to overwrite an existing baseline, trial, or summary. Archive the complete existing `output/` to a clearly named location before starting another run; preserve it for analysis. `orfs_work/` contains larger, regenerable ORFS artifacts. It may be archived for deeper inspection or left in place: new runs use unique variant names. Avoid deleting prior evidence before an archive has been checked.

## Evaluation and stopping policy

The search space contains 36 combinations: `ABC_AREA` = 0 or 1; `CORE_UTILIZATION` = 40, 55 or 70; `PLACE_DENSITY` = 0.60, 0.70 or 0.80; and `GPL_TIMING_DRIVEN` = 0 or 1. The baseline is `(1, 40, 0.80, 1)`. The clock period is fixed at 1000 ps and I/O delay at 100 ps.

The evaluator fills the provided templates, checks placeholders and required artifacts, runs `synth-report` and `finish`, and generates metadata. The parser records post-PnR standard-cell area in µm², total power in W, and setup worst slack and total negative slack (TNS) in ps. A positive worst slack indicates setup margin.

The score is dimensionless and lower is better:

```text
area / baseline_area + power / baseline_power
    + 1000 * max(0, -worst_slack_ps) / clock_period_ps
```

The area and power terms are baseline-normalized. Negative setup slack incurs a strong penalty; the penalty is not a formal guarantee that every timing-clean configuration ranks above every violating configuration. The baseline remains best unless a successful trial has a strictly lower score. The agent stops at the request limit, after three consecutive attempts without improvement, or when the search space has been exhausted. Invalid, duplicate, failed-request, and tool-failed attempts all count toward the request limit.

## Recorded experiment

The selected run completed the baseline and five successful proposals using TAMU `gpt-5.4`; it stopped at the trial limit. Trial 5 was the best observed configuration, not a claim of a global optimum.

| Metric | Baseline | Best observed trial 5 |
|---|---:|---:|
| Parameters: ABC / utilization / density / timing-driven | 1 / 40 / 0.80 / 1 | 1 / 70 / 0.80 / 1 |
| Area | 1390.25 µm² | 1380.87 µm² |
| Power | 0.00583206 W | 0.00577081 W |
| Worst setup slack | 105.244 ps | 125.247 ps |
| Setup TNS | 0 ps | 0 ps |
| Score | 2.0000 | 1.9828 |

For the complete per-attempt measurements and response records, consult `output/` and the separate report. Actual results may differ in later runs.
