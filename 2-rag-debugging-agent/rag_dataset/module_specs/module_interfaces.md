# Module interfaces the datapath must instantiate (THIS core)

The `datapath` instantiates seven modules and must connect to their EXACT ports. Wrong port names
are the most common integration compile error (`port '...' is not a port of ...`).

## New Assignment 2 unit modules (interfaces fixed by their specs - same for everyone)

```systemverilog
module pc_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        PCSrc,
    input  logic [31:0] PCTarget,
    output logic [31:0] PC,
    output logic [31:0] PCPlus4
);

module branch_unit (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  Funct3,
    input  logic        Branch,
    input  logic        Jump,
    output logic        BranchCond,
    output logic        PCSrc
);

module memory_access (
    input  logic [1:0]  MemRW,
    input  logic [2:0]  Funct3,
    input  logic [1:0]  AddrLSB,
    input  logic [31:0] StoreData,
    input  logic [31:0] ReadData,
    output logic [31:0] WriteData,
    output logic [3:0]  ByteEnable,
    output logic [31:0] LoadData
);
```

## Assignment 1 modules (alu, regfile, extend, controller)

These come from your own Assignment 1, so wire to the ports YOUR modules declare - do not rename
them. The controller in this core exposes control signals such as `RegWriteD`, `ImmSrcD`,
`ALUSrcAD`, `ALUSrcBD`, `MemRWD`, `ResultSrcD`, `BranchD`, `JumpD`, `ALUResultSrcD`, `ALUSelectD`,
`SubArithD`, `IllegalInstrD`, driven from `InstrD`; the ALU takes operands `A`/`B` with
`ALUSelect`/`SubArith` and returns `ALUResult`/`Sum`; `extend` takes `InstrD[31:7]` + `ImmSrcD` and
returns `ImmExtD`; the register file uses `a1`/`a2`/`a3`/`wd3`/`we3` with reads `rd1`/`rd2`.

Common bug: instantiating a module with guessed port names (e.g. `op`/`funct3` on the controller)
instead of the names the module actually declares. Read each module header and match it exactly.
