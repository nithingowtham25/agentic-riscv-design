# Assignment 3 - Package Contents

This file describes what is in the Assignment 3 student package and what each part is for. **The assignment itself
 -  the tasks, what to build, and setup - is in the handout
(`Assignment_3_Fall2026.pdf`), distributed separately on Canvas.** Read the handout first; use this file
as a map of the package.

## Directory structure

```
A3_student/
├── README_A3.md                     this file (package map)
├── check_setup.sh                   environment preflight - run this first
├── environment.yml                  conda environment (create with: conda env create -f environment.yml)
├── env.example                      copy to .env and add your API key(s)
│
├── core/                            the processor you build
│   ├── datapath_pipelined.sv            the 5-stage pipeline you build (fill its 3 TODOs)
│   └── submodules/
│       ├── alu.sv  regfile.sv  extend.sv  controller.sv   placeholder stubs - replace with your Assignment 1 modules
│       └── branch_unit.sv  memory_access.sv               placeholder stubs - replace with your Assignment 2 modules
│
├── docs/                            reference material
│   ├── pipeline_diagram.md              the 5 stages, registers, and where the 3 TODOs sit
│   ├── forwarding_truth_table.md        spec for TODO 1 (forwarding unit)
│   ├── hazard_unit_spec.md              spec for TODO 2 and TODO 3 (load-use stall, redirect/flush)
│   ├── coverage_metric.md               the 21 coverage bins your tests are scored on
│   └── required_invariants.md           the invariants your assertions must formalize
│
├── harness/                         local tools (run, don't edit)
│   ├── run.py                           runs your tests/assertions on your core; reports coverage
│   ├── task1_tests/*.hex                provided correctness tests for Task 1 (your core must pass all)
│   ├── assertions_template.sv           starter for your assertions (copy to results/assertions.sv)
│   ├── core_tb.sv                        testbench: runs a program on a core vs the reference model
│   ├── core_tb_cov.sv                    testbench with coverage instrumentation
│   └── core_tb_assert.sv                 testbench that binds your assertions into the core
│
├── scripts/                         setup helpers (see the Course Setup Guide)
│   └── install_icarus.sh                builds Icarus Verilog into your home dir (no sudo)
│
└── reference/                       the reference model (use, don't edit)
    ├── iss.py                            instruction-set simulator - the correctness oracle
    └── rv32i_isa.py                      RV32I instruction encoders for writing test programs
```

## What you create (not in the package)

You add these yourself; see the handout for details:

```
core/datapath_pipelined.sv        the pipeline you build (with its 3 TODOs filled in)
agent/run_agent.py  (+ your code)  your Verification Agent
results/
├── tests/*.hex                    test programs your agent generates
├── assertions.sv                  your assertions (copy of harness/assertions_template.sv, filled in)
├── coverage.json                  {"before":.., "after":..}
└── run_records/                   your agent's transcripts / model / token logs

<UIN>_A3_Report.pdf                  your report (PDF) - uploaded SEPARATELY, not in the zip
```

## Where to start

1. Run `bash check_setup.sh`.
2. Read `Assignment_3_Fall2026.pdf` (the handout, distributed separately on Canvas).
3. Follow the handout's tasks.
