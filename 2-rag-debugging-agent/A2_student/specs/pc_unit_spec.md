# Assignment 2 Module Specification: `pc_unit`

## Purpose

`pc_unit` maintains the 32-bit program counter for the simplified RV32I course processor. It provides the current PC and `PC + 4`, and selects between sequential execution and a control-flow target.

This Assignment 2 version is intentionally non-pipelined. Stall/flush behavior will be added in a later assignment.

## Required Interface

```systemverilog
module pc_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        PCSrc,
    input  logic [31:0] PCTarget,
    output logic [31:0] PC,
    output logic [31:0] PCPlus4
);
```

## Required Behavior

- `PC` is a 32-bit state element.
- `PCPlus4` is combinational and must always equal `PC + 32'd4`, wrapping modulo 2^32.
- State updates occur on the **rising edge** of `clk`.
- `reset` is synchronous, active high, and has highest priority.
- On a rising edge:
  - if `reset == 1`, set `PC = 32'h00000000`;
  - else if `PCSrc == 1`, set `PC = PCTarget`;
  - else set `PC = PCPlus4`.

## Notes

- The target is assumed to have already been formed by the datapath.
- `pc_unit` does not decide whether a branch is taken.
- `pc_unit` does not implement stalls, flushes, exceptions, or traps in Assignment 2.
- Instruction addresses used by the sample tests are word aligned, but the unit should copy `PCTarget` exactly when `PCSrc=1`.

## Integration Role

Later in Assignment 2:

```text
branch/jump decision -> PCSrc
branch/jump target   -> PCTarget
                         |
                         v
                     pc_unit
                         |
                         v
                  instruction address
```
