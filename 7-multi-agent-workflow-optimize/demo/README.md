# Binary-decimal converter demo

A tiny Python converter with three worker agents: **organizer** creates Bash
scripts and arranges files, **verifier** writes tests and catches a seeded
zero-conversion bug, and **builder** fixes it. Verification then runs again.
The orchestrator and all three workers use **Haiku** by default; workers inherit
the orchestrator model. This retains the Assignment 6 agent layout and native
telemetry; no packages or EDA tools are needed.

From the parent Assignment-7 or A7_student directory:

```bash
bash run.sh demo --telemetry on
# Optional model override:
bash run.sh demo --telemetry off --model haiku
```

Each run gets a fresh project copy. Inspect runs/<run>/project/workspace/ for
src/converter.py, tests/test_converter.py, scripts/, and results/. The final
results/decimal.json and results/binary.json both contain
`{"decimal": 10, "binary": "1010"}`, exercising opposite conversion directions.
The converter supports non-negative integers; binary strings may have leading
zeros. Invalid input is rejected. The starter intentionally mishandles decimal
zero so the agents have a small test-and-repair task.

Inspect runs/<run>/telemetry/report.md when telemetry is enabled. Registration
uses register_agents.py; telemetry uses the environment inherited from run.sh.
To change the next experiment, edit demo/ rather than a previous run copy.
