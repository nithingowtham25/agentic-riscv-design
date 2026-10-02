# ECEN 689 — Assignment 2: Debugging Agent

## Overview

This submission implements and evaluates an LLM-driven debugging agent for a single-cycle RV32I processor. The workflow combines:

- Retrieval-Augmented Generation (RAG) over the provided RV32I knowledge base.
- LLM-based RTL generation.
- Icarus Verilog compilation and simulation.
- Tool-output/status classification.
- Iterative RTL repair using simulator feedback.
- Keep-best and stop-on-pass policies.
- Controlled ablation experiments comparing baseline, RAG, and RAG+feedback.
- Final processor-level validation using the supplied sample programs.

This `README.md` is the student-created submission README required by Assignment 2.

---

## 1. Submission Folder Structure

The complete Assignment 2 folder contains the following important directories and files:

```text
A2_student/
├── README.md                         # This submission README
├── check_setup.sh                    # Environment / setup preflight checker
│
├── agent/                            # Debugging-agent implementation
│   ├── iterative_rtl_agent.py       # Main iterative RTL generation/repair agent
│   ├── tool_feedback.py             # Tool execution and feedback handling
│   ├── run_debug_agent.py            # Agent entry point
│   ├── llm_clients.py               # LLM/provider interface
│   └── io_utils.py                  # File/JSON utilities
│
├── rag/                              # Retrieval-Augmented Generation implementation
│   ├── index.py                     # RAG indexing/retrieval logic
│   └── build_index.py               # Index construction support
│
├── rag_dataset/                      # RV32I knowledge base used by RAG
├── specs/                            # Specifications for the four Assignment 2 modules
│
├── rtl/                              # Final eight-module processor RTL
│   ├── alu.sv                       # Assignment 1 module
│   ├── regfile.sv                   # Assignment 1 module
│   ├── extend.sv                    # Assignment 1 module
│   ├── controller.sv                # Assignment 1 module
│   ├── pc_unit.sv                   # Assignment 2 module
│   ├── branch_unit.sv               # Assignment 2 module
│   ├── memory_access.sv             # Assignment 2 module
│   └── datapath.sv                  # Assignment 2 module
│
├── rtl_good_backup/                 # Passing Task 3 processor snapshot
├── bugs/                            # Instructor-provided seeded-bug RTL
├── testbench/                       # Module/integration testbenches
├── vectors/                         # Test vectors
├── programs/sample/                 # Integrated sample programs
│
├── logs/                            # Complete experiment/run records
│   ├── task1_rag_queries.txt
│   ├── pc_unit_smoke.json
│   ├── pc_unit.json
│   ├── branch_unit.json
│   ├── memory_access.json
│   ├── datapath.json
│   ├── seeded_repairs/
│   └── ablation/
│
├── analysis/                        # Generated quantitative/qualitative analysis
│   ├── task1_rag_observation.md
│   ├── task2_debugging_agent.md
│   ├── task3_generate_and_integrate.md
│   ├── seeded_bug_summary.md
│   ├── task4_ablation.md
│   ├── ablation_summary.md
│   └── task5_analysis
│
└── scripts/                         # Reproducibility and execution scripts
    ├── run_task1_rag.sh
    ├── copy_a1_rtl.sh
    ├── run_task2_smoke.sh
    ├── run_task3_processor.sh
    ├── run_seeded_repairs.sh
    ├── run_task4_ablation.sh
    ├── run_task5_final.sh
    ├── run_all_sample.sh
    └── summarize_assignment2.py
```

The package also contains the supplied test infrastructure and supporting files from the instructor. The structure above identifies the files and directories most relevant to the submitted tasks and reproducibility.

---

## 2. Required Files and Evidence by Task

### Task 1 — RAG Retrieval

**Implementation**
- `rag/index.py`
- `rag/build_index.py`
- `rag_dataset/`

**Run record**
- `logs/task1_rag_queries.txt`

**Analysis**
- `analysis/task1_rag_observation.md`

**Reproduce**
```bash
bash scripts/run_task1_rag.sh
```

This builds the local `.rag_index/` and records the five representative top-k retrieval examples.

---

### Task 2 — Debugging Agent

**Implementation**
- `agent/iterative_rtl_agent.py`
- `agent/tool_feedback.py`
- `agent/run_debug_agent.py`
- `agent/llm_clients.py`
- `agent/io_utils.py`

**Run record**
- `logs/pc_unit_smoke.json`

**Analysis**
- `analysis/task2_debugging_agent.md`

**Reproduce**
```bash
bash scripts/run_task2_smoke.sh tamu gpt-5.4
```

The smoke test exercises the end-to-end generate → write RTL → execute tool flow → classify result → log result path.

---

### Task 3 — Processor Generation, Integration, and Seeded Repair

**Module specifications**
- `specs/`

**Final eight-module RTL**
- Assignment 1: `rtl/alu.sv`, `rtl/regfile.sv`, `rtl/extend.sv`, `rtl/controller.sv`
- Assignment 2: `rtl/pc_unit.sv`, `rtl/branch_unit.sv`, `rtl/memory_access.sv`, `rtl/datapath.sv`

**Passing integrated snapshot**
- `rtl_good_backup/`

**Clean-generation run records**
- `logs/pc_unit.json`
- `logs/branch_unit.json`
- `logs/memory_access.json`
- `logs/datapath.json`

**Seeded-repair records**
- `logs/seeded_repairs/`

The seeded-repair directory contains the four required repair records for `pc_unit`, `branch_unit`, `memory_access`, and `datapath`.

**Analysis**
- `analysis/task3_generate_and_integrate.md`
- `analysis/seeded_bug_summary.md`

**Reproduce clean generation/integration**
```bash
bash scripts/copy_a1_rtl.sh /path/to/final_rtl (from Assignment 1)
bash scripts/run_task3_processor.sh tamu gpt-5.4
```

**Reproduce seeded repairs**
```bash
bash scripts/run_seeded_repairs.sh tamu gpt-5.4
```

`rtl_good_backup/` is kept at the package root and must not be placed inside `rtl/`.

---

### Task 4 — Ablation Study

**Experiment records**
- `logs/ablation/`

**Quantitative summary**
- `analysis/ablation_summary.md`

**Discussion**
- `analysis/task4_ablation.md`

**Reproduce**
```bash
bash scripts/run_task4_ablation.sh tamu gpt-5.4
```

The ablation performs three runs for each required arm:

- **Part A:** Baseline vs. RAG vs. RAG+feedback for unseeded datapath generation.
- **Part B:** RAG vs. RAG+feedback for seeded datapath repair.

The script preserves the individual JSON records under `logs/ablation/`.

**Generate/update summary files**
```bash
python scripts/summarize_assignment2.py
```

This writes:
- `analysis/ablation_summary.md`
- `analysis/seeded_bug_summary.md`

---

### Task 5 — Final Processor Validation

**Passing processor snapshot**
- `rtl_good_backup/`

**Final execution log**
- `logs/task5_final_processor.log`

**Analysis**
- `analysis/task5_analysis`

**Reproduce**
```bash
bash scripts/run_task5_final.sh
```

This restores the passing Task 3 processor snapshot into `rtl/` and runs:

```bash
bash scripts/run_all_sample.sh
```

The final integration suite uses the 14 supplied sample programs in `programs/sample/`.

---

## 3. Complete Reproduction Sequence

Run the following from the package root after completing the one-time environment setup described by the instructor's course setup guide.

### Step 0 — Preflight
```bash
bash check_setup.sh
```

### Step 1 — RAG
```bash
bash scripts/run_task1_rag.sh
```

### Step 2 — Debugging-agent smoke test
```bash
bash scripts/run_task2_smoke.sh tamu gpt-5.4
```

### Step 3 — Copy Assignment 1 RTL and generate/integrate the processor
```bash
bash scripts/copy_a1_rtl.sh /path/to/1-rtl-tb-agent/2_verilog_blocks_and_testbenches/final_rtl
bash scripts/run_task3_processor.sh tamu gpt-5.4
```

### Step 3b — Seeded repairs
```bash
bash scripts/run_seeded_repairs.sh tamu gpt-5.4
```

### Step 4 — Ablation
```bash
bash scripts/run_task4_ablation.sh tamu gpt-5.4
python scripts/summarize_assignment2.py
```

### Step 5 — Final integration
```bash
bash scripts/run_task5_final.sh
```

---

## 4. Fixed Experimental Policy

The documented experiments use the same `tamu` provider and `gpt-5.4` model configuration.

The debugging agent uses the following fixed policy:

- Maximum of five repair iterations after iteration 0.
- Stop immediately when the RTL passes.
- Keep the best RTL according to the supplied status ordering:
  `compile_error < sim_fail < pass`.
- Restore the previous best RTL if a repair produces a worse status.
- RAG retrieval is enabled for the `rag` and `rag_feedback` arms.
- Iterative simulator/tool feedback is enabled only for the `rag_feedback` arm.

These settings are kept consistent across the controlled ablation experiments.

---

## 5. Results and Evidence Map

| Task | Primary evidence | Supporting analysis |
|---|---|---|
| Task 1 | `logs/task1_rag_queries.txt` | `analysis/task1_rag_observation.md` |
| Task 2 | `logs/pc_unit_smoke.json` | `analysis/task2_debugging_agent.md` |
| Task 3 — clean generation | `logs/pc_unit.json`, `logs/branch_unit.json`, `logs/memory_access.json`, `logs/datapath.json` | `analysis/task3_generate_and_integrate.md` |
| Task 3 — seeded repair | `logs/seeded_repairs/*.json` | `analysis/seeded_bug_summary.md` |
| Task 4 | `logs/ablation/*.json` | `analysis/ablation_summary.md`, `analysis/task4_ablation.md` |
| Task 5 | `logs/task5_final_processor.log` | `analysis/task5_analysis` |

The final eight-module processor is stored in `rtl/`, while `rtl_good_backup/` preserves the passing Task 3 snapshot used for final validation.

---

## 6. Submission Packaging

After collecting the required logs and analysis, the complete Assignment 2 folder is packaged as:

```text
337001954_A2.zip
```

The final report is submitted separately as:

```text
337001954_A2_Report.pdf
```