# Assignment 7 setup guide

Run the hardware experiments on Olympus (`olympus.ece.tamu.edu`) from your scratch directory. The commands below assume you are inside the extracted student package.

## 1. Reuse the Assignment 6 environment

Use the Claude Code, TAMU AI Chat, Icarus Verilog and ORFS/OpenROAD setup that worked for Assignment 6. Check the main tools before a measured run:

```bash
claude --version
python3 --version
iverilog -V
vvp -V
```

The official TAMU Claude Code configuration uses:

```bash
export ANTHROPIC_BASE_URL="https://chat-api.tamu.ai/api"
export ANTHROPIC_AUTH_TOKEN="YOUR_TAMU_API_KEY"
export ANTHROPIC_MODEL="YOUR_SUPPORTED_MODEL_ID"
```

If your A6 launcher reads its own `.env`, keep that convention. For example, the supplied test framework expects `baseline_framework/.env` containing `TAMUS_AI_CHAT_API_KEY="YOUR_TAMU_API_KEY"`. Never submit this file or your key.

If your A6 Icarus environment already exists, load it as before:

```bash
export PATH="$SCRATCH/a5icarus/bin:$PATH"
```

Keep the same model and generation settings for baseline and revised runs.

## 2. Prepare the two frameworks

Put your completed Assignment 6 project in `baseline_framework/`. It must contain `run_orchestrator.sh` and must still perform the A6 `memory_access` generation, verification, debugging and physical-design flow. Do not change it before collecting baseline evidence.

Leave `revised_framework/` empty until Task 3. Then copy the baseline into it and make only the workflow changes supported by your Task 2 analysis.

## 3. Install and check telemetry

```bash
python3 telemetry/install.py
bash run.sh demo --telemetry on --model "$ANTHROPIC_MODEL" --out runs/demo
```

The demo uses three subagents to organize, test and repair a binary-decimal converter. During a run, the launcher prints collector status, workflow status, elapsed time every 30 seconds and the final report location. Agent output is saved in `runs/<run>/claude/`.

Open `runs/demo/telemetry/report.md`. Check `agents.csv`, `tools.csv`, `requests.csv`, `spans.csv` and `timer.json`. Missing usage fields mean unavailable data, not zero usage.

## 4. Run baseline and revised experiments

Run the unchanged A6 framework without human intervention:

```bash
bash run.sh baseline --telemetry on --out runs/baseline-1
bash run.sh baseline --telemetry on --out runs/baseline-2
bash run.sh baseline --telemetry on --out runs/baseline-3
```

Aim for three runs. Depending on your model and API allowance, you may report fewer, but at least one complete run is required. Use a fresh output path for every attempt and include failures.

After completing Task 2, run the revised framework the same number of times with the same model, specifications, evaluator and generation settings:

```bash
bash run.sh revised --telemetry on --out runs/revised-1
bash run.sh revised --telemetry on --out runs/revised-2
bash run.sh revised --telemetry on --out runs/revised-3
```

Each run uses a fresh project copy. Edit `baseline_framework/` or `revised_framework/`, never `runs/<run>/project/`. Use `--telemetry off` only for troubleshooting; measured runs require telemetry.

## 5. Find and submit the evidence

Each run contains:

```text
runs/<run>/
├── project/
├── claude/stdout.log
├── claude/stderr.log
├── telemetry/report.md
├── telemetry/timer.json
└── result.json
```

The telemetry folder also contains CSV and raw OpenTelemetry files. Judge RTL correctness from the A6 simulation and synthesis reports, not from `result.json` alone.

Submit the package and report listed in the handout. Include all attempted baseline and revised runs. Remove API keys, `.env`, downloaded collector binaries, container images and golden RTL before submission.
