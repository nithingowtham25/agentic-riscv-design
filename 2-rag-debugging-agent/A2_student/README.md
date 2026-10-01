# ECEN 689 Assignment 2 Debugging Agent

This submission builds a retrieval-augmented debugging agent for a single-cycle RV32I processor. The agent generates RTL, runs the supplied Icarus/test flow, classifies tool feedback, retrieves relevant RAG context when requested, and iteratively repairs RTL under the fixed five-repair keep-best policy.

## Submission layout

- `agent/`: debugging-agent implementation. Student work is limited to the marked phases in `iterative_rtl_agent.py` and `tool_feedback.py`.
- `rag/`: semantic retrieval implementation. Student work is limited to the marked Phase A in `rag/index.py`.
- `rtl/`: the eight final processor modules: four carried from Assignment 1 and four Assignment 2 modules.
- `rtl_good_backup/`: Task 3 snapshot of the integrated passing processor. It remains at the package root, never inside `rtl/`.
- `logs/`: complete JSON run records. `logs/seeded_repairs/` contains the four seeded-bug repairs and `logs/ablation/` contains Task 4 runs.
- `analysis/`: generated summaries for the seeded-bug and ablation results.
- `scripts/`: supplied checkers plus reproducibility scripts described below.
- `4_report/`: final report source/output if created for submission. The final PDF is submitted separately and is not placed in the ZIP.

## Reproduce the results

Run all commands from the package root after activating the prepared Assignment 2 environment.

```bash
bash check_setup.sh
bash scripts/run_task1_rag.sh
bash scripts/copy_a1_rtl.sh /path/to/1-rtl-tb-agent/2_verilog_blocks_and_testbenches/final_rtl
bash scripts/run_task2_smoke.sh tamu gpt-5.4
bash scripts/run_task3_processor.sh tamu gpt-5.4
bash scripts/run_seeded_repairs.sh tamu gpt-5.4
bash scripts/run_task4_ablation.sh tamu gpt-5.4
python scripts/summarize_assignment2.py
bash scripts/run_task5_final.sh
```

`run_task1_rag.sh` builds `.rag_index/` and saves five top-k retrieval examples in `logs/task1_rag_queries.txt`.

`run_task2_smoke.sh` saves `logs/pc_unit_smoke.json`.

`run_task3_processor.sh` generates the three independent modules, then datapath, runs the supplied integration suite, and creates `rtl_good_backup/` only after a passing integration run.

`run_seeded_repairs.sh` saves one JSON run record per supplied seeded bug under `logs/seeded_repairs/`.

`run_task4_ablation.sh` performs three runs for each required arm. It removes only `rtl/datapath.sv` between runs, as required, and retains every JSON record under `logs/ablation/`. It intentionally continues after an individual failed run so the complete controlled dataset is preserved.

`scripts/summarize_assignment2.py` writes `analysis/ablation_summary.md` and `analysis/seeded_bug_summary.md`. The ablation table reports pass rate, failures, and mean/range repair counts for successful runs only.

`run_task5_final.sh` restores the Task 3 processor snapshot and reruns the supplied full integration suite.

## Fixed experimental policy

All experiment arms use `gpt-5.4` with the same provider/model setting. The agent allows at most five repairs after iteration 0, stops on the first pass, and restores the prior best RTL if a repair has a lower provided status rank. RAG retrieval is enabled only for the `rag` and `rag_feedback` arms; iterative tool feedback is enabled only for `rag_feedback`.

## Submission reminders

Create `<UIN>_A2.zip` from this complete folder after collecting all logs and analysis. Submit `<UIN>_A2_Report.pdf` separately. Do not include `.env`, API keys, tokens, or other secrets in either submission.