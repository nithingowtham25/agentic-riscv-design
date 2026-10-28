# ECEN 689 Assignment 4: Physical Design Agent

This package runs the fixed, verified Assignment 3 processor through ASAP7 OpenROAD-flow-scripts (ORFS), measures post-route PPA, and requests tool-setting proposals from TAMU AI Chat. The required launcher is `run_lab.sh`; the scripts below preserve its terminal output.

## Folder guide

```text
4-physical-design-agent/
  core/                         Assignment 3 RTL, fixed for every experiment
  student_code/run_agent.py     evaluator, metrics, TAMU client and optimization loop
  student_code/                 supplied configuration, search space and tool helpers
  template/                     supplied config and timing templates
  container/                    supplied container configuration
  scripts/run_preflight.sh      environment check with terminal logging
  scripts/run_experiment.sh     required launcher with terminal logging
  output/terminal_logs/         timestamped output from these scripts
  output/baseline/              baseline config, logs, metadata and result.json
  output/trial_001/ ...         each proposal, response, status and tool evidence
  output/summary.json           baseline, best, attempts and stop reason
  orfs_work/                    ORFS intermediate work (not result records)
  README_A4.md                  provided package map
```

## Run on Olympus, Grace or Faster

1. In a cluster shell, enter the assignment directory and activate the course environment. Follow the course setup guide for the correct compute allocation, container, and internet/proxy access. The supplied launcher handles the container and Grace WebProxy setup. Keep your TAMU key in the existing `.env` or export `TAMUS_AI_CHAT_API_KEY`; never include credentials in submitted files.
2. Run `bash scripts/run_preflight.sh`. Inspect the printed path to the terminal log and resolve any reported setup failures. The preflight may create local container/cache files.
3. Run `bash scripts/run_experiment.sh --provider tamu --trials 5 --model gpt-5.4`. Select one available model and keep the same model and generation settings across reported runs. The default model if `--model` is omitted is the supplied `gpt-5.4-mini`. The script calls `bash run_lab.sh` inside the provided environment. Physical design can take substantial time; use the cluster allocation required by your site.
4. Inspect `output/baseline/result.json`, every `output/trial_*/result.json`, `output/summary.json`, and `output/terminal_logs/`. Share these records and logs for analysis. The first proposal is attempt 1; the baseline is not an attempt. If baseline or metrics parsing fails, inspect its log and metadata and report the failure before continuing.
5. Before a new independent run, move the complete existing `output/` to a clearly named archive outside the package, then run again. The agent refuses to overwrite existing baseline, trial, or summary records. Keep a copy of each run for the report, and place the intended complete results in `output/` before submission.

## Evaluation and stopping policy

Each trial gets its own config and fixed timing constraints, and a unique ORFS variant. The agent validates all four parameters and rejects malformed, invalid, or duplicate proposals before invoking tools. It records failed synthesis, PnR, artifact, and metadata checks. `metadata.json` is parsed for post-PnR area (um^2), power (W), WNS and TNS (ps); inspect the metadata and report units on the first real run.

The dimensionless score is `area / baseline_area + power / baseline_power + 1000 * max(0, -WNS_ps) / clock_period_ps`; lower is better. It penalizes negative WNS, but the penalty does not guarantee every timing-violating result ranks below every timing-clean result. Baseline remains best unless a successful trial has a strictly lower score. The search stops at the proposal limit, after three consecutive attempts without improvement, or when all 36 configurations have been attempted. Provider temperature is left at the provider default and is recorded as such. Every request counts, including failures and rejections.

## Deliverables

Submit `<UIN>_A4.zip` containing the complete provided package, source, fixed core, templates, README, and `output/` evidence. Exclude `.env`, credentials and secrets; avoid including unnecessary container caches or scratch data. Submit `<UIN>_A4_Report.pdf` separately outside the ZIP. The report must explain the evaluator, feedback and validation; units and score; each attempt; baseline versus best; stopping policy; provider/model/settings; and evidence-based findings.
