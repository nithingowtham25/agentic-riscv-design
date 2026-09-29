# Assignment 2 Module Specification: `branch_unit`

## Purpose

`branch_unit` evaluates RV32I conditional branch comparisons and determines whether the processor should redirect the PC. It consumes the two register operands and the branch `funct3` field.

## Required Interface

```systemverilog
module branch_unit (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  Funct3,
    input  logic        Branch,
    input  logic        Jump,
    output logic        BranchCond,
    output logic        PCSrc
);
```

## Branch Conditions

When `Branch=1`, `Funct3` has the RV32I meaning below:

| `Funct3` | Instruction | `BranchCond` |
|---|---|---|
| `000` | BEQ  | `A == B` |
| `001` | BNE  | `A != B` |
| `100` | BLT  | signed `A < B` |
| `101` | BGE  | signed `A >= B` |
| `110` | BLTU | unsigned `A < B` |
| `111` | BGEU | unsigned `A >= B` |

`010` and `011` are not legal RV32I branch conditions in the course subset. For deterministic unit testing, set `BranchCond=0` for those encodings.

## PC Redirection

```text
PCSrc = Jump OR (Branch AND BranchCond)
```

Therefore:

- `Jump=1` always redirects the PC regardless of `Funct3`.
- A conditional branch redirects the PC only when its comparison is true.
- If `Branch=0` and `Jump=0`, `PCSrc=0`.

## Important Signedness Requirement

BLT/BGE must interpret `A` and `B` as signed 32-bit two's-complement values. BLTU/BGEU must compare the same bit patterns as unsigned values.

## Integration Role

`Branch` and `Jump` come from the Assignment 1 controller. `A` and `B` are the two register-file read values. `PCSrc` drives the Assignment 2 `pc_unit`.
