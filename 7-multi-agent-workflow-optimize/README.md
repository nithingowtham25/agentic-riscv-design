# Assignment 7 student package

Read the [assignment handout](Assignment_7_Fall2026.pdf) and [setup guide](Setup_Guide_A7.pdf) ([Markdown](setup.md)). This assignment uses the same `memory_access` design task as Assignment 6. You will run your A6 framework with telemetry, analyze the evidence, then revise the framework.

## Directory layout

```text
A7_student/
├── baseline_framework/   # Your unchanged Assignment 6 framework
├── revised_framework/    # Your Task 3 framework
├── demo/                 # Small telemetry check
├── specs/                # memory_access specifications
├── telemetry/            # Provided OpenTelemetry tools
├── run.sh
├── setup.md
└── runs/
    └── baseline-<run>/
        ├── project/      # Fresh copy used for this run
        ├── claude/       # Agent stdout and stderr
        ├── telemetry/    # Report, CSVs, raw data and timer.json
        └── result.json   # Process status and elapsed time
```

## Run the assignment

Install the collector and check it with the three-agent converter demo:

```bash
python3 telemetry/install.py
bash run.sh demo --telemetry on --model YOUR_TAMU_MODEL_ID --out runs/demo
```

Put your completed A6 project in `baseline_framework/`. Keep it unchanged for the baseline experiment and run the same `memory_access` task without human intervention:

```bash
bash run.sh baseline --telemetry on --out runs/baseline-1
```

Aim for three baseline runs. Depending on your model and API allowance, you may report fewer, but at least one complete run is required. Use a new output path for every attempt and include failures.

For Task 3, copy the baseline into `revised_framework/`, implement an evidence-based workflow change, and run the same number of experiments with the same model, specifications and evaluator:

```bash
bash run.sh revised --telemetry on --out runs/revised-1
```

The launcher prints collector status, workflow start and exit, an elapsed-time update every 30 seconds, and the final report path. Full agent output stays in `runs/<run>/claude/`. Open `runs/<run>/telemetry/report.md`; `timer.json` records workflow wall time and exit code.

## Analysis and submission

Create one table with one row per run. Include at least two graphs: time by agent or tool, and token use or call count by agent. Use the hardware reports for correctness and telemetry for agent behavior. A successful process exit does not prove that the RTL is correct.

Submit `<UIN>_A7.zip` containing `baseline_framework/`, `revised_framework/`, `specs/`, `telemetry/`, `run.sh`, this README and `runs/`. Submit `<UIN>_A7_Report.pdf` separately. Remove API keys, collector binaries and golden RTL before submission.

See [telemetry/README.md](telemetry/README.md) for collected fields and limitations. Use `--telemetry off` to disable collection.
