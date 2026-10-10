# Coverage metric (the exact bins your coverage is scored on)

Your Verification Agent's coverage (Task 3) is measured over **21 fixed bins** across three dimensions.
A bin is "hit" when at least one of your test programs, **that passes on your correct core**, puts the
pipeline in that situation. Coverage % = bins hit / 21. Only passing runs count (a test that produces
the wrong result earns no coverage), so you cannot inflate coverage with broken tests.

Your tests are run on your correct core with a coverage-instrumented testbench that records, each
cycle, the instruction in Execute and the hazard/control events resolved that cycle, then tallies bins.

## Dimension 1: instruction type (9 bins)
One bin per RV32I instruction group the core supports:
`OP_REG, OP_IMM, OP_LOAD, OP_STORE, OP_BRANCH, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC`.

## Dimension 2: hazard scenario (7 bins)
`fwdA_mem`  - forward source A from the Memory stage
`fwdA_wb`   - forward source A from the Writeback stage
`fwdB_mem`  - forward source B from the Memory stage
`fwdB_wb`   - forward source B from the Writeback stage
`no_forward` -  a cycle with neither operand forwarded
`load_use_stall` - a load-use stall actually occurred
`flush`     - a pipeline flush actually occurred

## Dimension 3: control path (5 bins)
`branch_taken, branch_not_taken, jal, jalr, no_control`.

## How to close holes?
Your own runs (via the harness) report which bins are missed. To hit them you must
write programs that *create* the situation, e.g. `fwdB_wb` needs a producer whose result is consumed as
the second operand two instructions later; `load_use_stall` needs a load immediately followed by a
dependent instruction; `jalr` needs a `JALR`. This is the coverage-driven loop: measure -> find the
missed bins -> generate targeted tests -> re-measure.
