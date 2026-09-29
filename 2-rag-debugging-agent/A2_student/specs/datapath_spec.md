# Assignment 2 Module Specification: `datapath`

## Purpose

`datapath` is the first processor-integration module in the course. It combines the four verified Assignment 1 modules with the three new Assignment 2 units to form a small **non-pipelined RV32I processor core** with external instruction- and data-memory interfaces.

The goal is not yet to build the final five-stage processor. The purpose of this module is to expose multi-module integration and debugging problems that can be addressed with RAG and iterative EDA feedback.

## Required Interface

```systemverilog
module datapath (
    input  logic        clk,
    input  logic        reset,

    input  logic [31:0] Instr,
    input  logic [31:0] ReadData,

    output logic [31:0] PC,
    output logic [31:0] DataAdr,
    output logic [31:0] WriteData,
    output logic [3:0]  ByteEnable,
    output logic        MemRead,
    output logic        MemWrite,
    output logic        IllegalInstr
);
```

## Required Submodules

The datapath must use the verified Assignment 1 modules:

```text
alu
regfile
extend
controller
```

and the new Assignment 2 modules:

```text
pc_unit
branch_unit
memory_access
```

The Assignment 1 module interfaces and control encodings must not be changed for the required integration.

## Instruction Fields

Use the standard RV32I fields:

```text
rs1   = Instr[19:15]
rs2   = Instr[24:20]
rd    = Instr[11:7]
funct3= Instr[14:12]
opcode= Instr[6:0]
```

`Instr[31:7]` is passed to `extend`.

## Operand Selection

The Assignment 1 controller outputs `ALUSrcAD` and `ALUSrcBD`:

```text
ALUSrcAD = 0 -> ALU A = register-file rd1
ALUSrcAD = 1 -> ALU A = PC

ALUSrcBD = 0 -> ALU B = register-file rd2
ALUSrcBD = 1 -> ALU B = ImmExtD
```

## ALU / Address Behavior

Instantiate the Assignment 1 ALU using `ALUSelectD` and `SubArithD`.

For load/store and control-target additions, the ALU's `Sum` output provides the calculated address/target.

```text
DataAdr = Sum
```

for memory accesses.

## Branch and Jump Behavior

Pass the original register operands, `Instr[14:12]`, `BranchD`, and `JumpD` to `branch_unit`.

The default target is the ALU `Sum`:

- branch: `PC + B-immediate`;
- JAL: `PC + J-immediate`;
- JALR: `rs1 + I-immediate`.

For JALR only, clear target bit 0 before sending the target to `pc_unit`:

```text
PCTarget = {Sum[31:1], 1'b0}
```

For other branches/jumps:

```text
PCTarget = Sum
```

## Execution Result Selection

The Assignment 1 controller uses `ALUResultSrcD` to select an alternate IEU result.

```text
ALUResultSrcD = 0 -> IEUResult = ALUResult
ALUResultSrcD = 1 and JumpD=0 -> IEUResult = ImmExtD   (LUI)
ALUResultSrcD = 1 and JumpD=1 -> IEUResult = PCPlus4   (JAL/JALR link)
```

## Memory Access and Writeback

Pass `MemRWD`, `Instr[14:12]`, `DataAdr[1:0]`, register-file `rd2`, and external `ReadData` to `memory_access`.

External memory control:

```text
MemRead  = (MemRWD == 2'b10)
MemWrite = (MemRWD == 2'b01)
```

Writeback to the register file:

```text
ResultSrcD = 3'b001 -> WritebackData = LoadData
otherwise           -> WritebackData = IEUResult
```

The register file uses `RegWriteD`, `Instr[11:7]`, and the selected writeback data.

## Illegal Instructions

```text
IllegalInstr = IllegalInstrD
```

The Assignment 1 controller already suppresses architectural side effects for illegal instructions.

## Memory Model Assumptions

The processor does not contain instruction or data SRAMs internally in Assignment 2.

The test environment supplies:

```text
PC       -> instruction-memory address
Instr    <- instruction-memory word

DataAdr  -> data-memory address
ReadData <- data-memory word
WriteData / ByteEnable / MemWrite -> data-memory write interface
```

## Assignment 2 Scope

This is intentionally a **non-pipelined** integration target. Do not add:

- pipeline registers;
- forwarding;
- stalls;
- flush control;
- caches;
- privileged/CSR logic;
- branch prediction.

Those features are reserved for later assignments.
