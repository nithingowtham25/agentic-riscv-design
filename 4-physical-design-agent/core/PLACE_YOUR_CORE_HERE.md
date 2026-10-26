# Place your Assignment 3 pipelined core here

This assignment optimizes the **physical quality (PPA)** of the five-stage
pipelined RV32I core you built and verified in Assignment 3. The RTL is
**frozen** in this assignment -- you tune synthesis and place-and-route
parameters, not the RTL.

Copy your verified Assignment 3 core into this directory so the layout is:

```
core/
  datapath_pipelined.sv          your top-level pipelined datapath
  submodules/
    alu.sv
    regfile.sv
    extend.sv
    controller.sv
    branch_unit.sv
    memory_access.sv
```

Requirements:

- The top module must be named `datapath_pipelined` with its Assignment 3 ports
  (the flow and the timing constraint reference the `clk` port by name).
- Use the exact filenames above; `student_code/config.py` lists them.
- Use the core that passes your Assignment 3 functional tests. The flow does not
  re-verify functionality -- submitting a broken core only wastes synthesis runs.
