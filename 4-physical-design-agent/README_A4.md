# Assignment 4 - Package Contents

This file is only a map of the package. **The assignment itself - the tasks, what
to build, how you are graded, and the environment setup - is in the handout
(`Assignment_4_Fall2026.pdf`) and the Course Setup Guide, distributed separately
on Canvas.** Read those first; use this file to find your way around the package.

## Directory structure

```
A4_student/
├── README_A4.md                     this file (package map)
├── check_environment.sh             environment preflight - run this first
├── run_lab.sh                       launcher: runs your agent inside the ORFS container
├── env.example                      copy to .env and set your TAMU API key
│
├── container/                       course EDA image tooling (do not edit)
│   ├── stack.env                        pinned ORFS image + tool versions
│   ├── pull_sif.sh                      pulls/verifies the course Singularity image
│   └── runtime_checks.sh                shared Singularity helper functions
│
├── template/                        ORFS input templates (filled per trial)
│   ├── config_template.mk               config.mk with {PLACEHOLDER} fields
│   └── constraint_template.sdc          fixed timing constraints
│
├── student_code/                    provided building blocks (use, don't rewrite)
│   ├── config.py                        fixed paths, design name, timing constants
│   ├── search_space.py                  legal parameters, valid_params, baseline
│   ├── tool_runner.py                   ORFS Make-target wrappers + artifact paths
│   └── io_utils.py                      text / JSON file helpers
│
├── tests/
│   └── test_infrastructure.py           smoke tests for the provided building blocks
│
└── core/                            you place your Assignment 3 pipelined core here
    └── PLACE_YOUR_CORE_HERE.md          instructions for dropping in your core
```

## What you create (not in the package)

You write these yourself; see the handout for details:

```
student_code/run_agent.py            your agent entry point
  (+ your LLM client, metric parsing/scoring, loop - as modules you add)
output/                              your agent's results
├── baseline/result.json
├── trial_*/result.json
└── summary.json
<UIN>_A4_Report.pdf                  your report (PDF) - uploaded SEPARATELY, not in the zip
```
