# Native OpenTelemetry

Students use `bash run.sh baseline --telemetry on`. There are no telemetry hooks, snapshots, role mappings or extra settings to add to agent code.

The launcher starts the official OpenTelemetry Collector on a free loopback port, sets Claude's documented OTel environment variables, runs the student's normal command, then gracefully stops the collector and exports local files. Nothing is sent to a hosted monitoring backend. Claude model usage is still billed normally.

Files here:

- `install.py`: one-time download of official collector 0.165.0, verified against its published SHA-256.
- `collector.yaml`: OTLP receiver and local file exporters.
- `run.py`: collector lifecycle and process environment.
- `export.py`: native OTLP JSON to CSV/report. It does not infer model activity from custom hooks.

## Your own entry point

Keep the existing project launcher, or run another command directly:

```bash
python3 telemetry/run.py --out /new/run/telemetry -- python3 my_agents.py
```

Any Claude CLI processes started by that Python program inherit the environment. Native Claude subagents are instrumented by Claude. If your orchestrator strips environment variables or uses remote workers, forward the OTel configuration explicitly. Non-Claude model clients must provide their own OTel instrumentation and may need a different report mapping. Claude itself does not forward OTEL_* settings to Bash tools or hooks, so a separate Claude process spawned from inside an agent's Bash tool needs explicit configuration.

## Outputs

`report.md` and `summary.json` summarize received events. CSVs include `agents`, `tools`, `requests`, `messages`, `decisions`, `spans`, `events`, and `metrics`. Raw `logs.jsonl`, `traces.jsonl` and `metrics.jsonl` retain the native data. Span parent IDs describe the call tree; permission decisions are distinct from an agent's reasoning.

## Progress and timing

The launcher prints short status lines while full agent output is written to `claude/`:

```text
[telemetry] collector ready; output: ...
[telemetry] workflow started ...
[telemetry] workflow running; elapsed 00:00:30
[telemetry] workflow exited with code 0; elapsed 00:01:12
[telemetry] report ready: ...
```

`timer.json` records workflow wall time and exit code. These values also appear in `summary.json` and `report.md`. The messages describe collection and process status; use the hardware evaluator to decide whether generated RTL is correct.

API-event token/cost totals are summed once; periodic metrics and subagent final-context sizes are not added again. An observed Claude 2.1.311 smoke test showed that CLI token totals excluded subagents while its total cost included them; native OTel captured both parent and subagent API events. This is an observed version-specific result, not a promise about every provider/version.

Counts cover received completed events. Missing exports, interruptions, or beta-tracing availability can leave incomplete evidence. Empty telemetry is flagged, not interpreted as zero usage. Raw collector files and collector.log are preserved for troubleshooting.

Detailed native tracing is beta. Tool parameters and public assistant text are enabled for local analysis and may contain student code. Prompts and raw API bodies are disabled, but native logs can still contain account metadata. Hidden reasoning is not recovered. No per-file hashing is performed. Functional correctness and PPA come from project evaluators.

`off` disables this launcher's OTel exporters; administrator-managed Claude settings may take precedence. Ordinary process and project evaluator logs remain active.

Sources: [Claude monitoring](https://code.claude.com/docs/en/monitoring-usage), [official Collector](https://github.com/open-telemetry/opentelemetry-collector-releases), [file exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/fileexporter).
