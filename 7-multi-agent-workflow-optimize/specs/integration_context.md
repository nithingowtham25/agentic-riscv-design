# Integration context for `memory_access` (Assignment 6 target)

`memory_access` is the Memory-stage data-formatting block of the five-stage pipelined RV32I core
built in Assignments 1-4 (`core/datapath_pipelined.sv`, with `alu`, `regfile`, `extend`,
`controller`, `branch_unit` in `core/submodules/`). The generated module is linked into that core
unchanged, so the module name, port names and port widths in `memory_access_spec.md` are a hard
contract.

How the core instantiates it (Memory stage):

```systemverilog
assign DataAdr   = SumM;                 // ALU address computed in Execute
assign MemRead   = (MemRWM == 2'b10);
assign MemWrite  = (MemRWM == 2'b01);
memory_access ma(.MemRW(MemRWM), .Funct3(Funct3M), .AddrLSB(DataAdr[1:0]),
    .StoreData(WriteDataM),              // raw rs2 value (already forwarded)
    .ReadData(ReadData),                 // 32-bit word read from data memory
    .WriteData(WriteData),               // byte-lane-aligned store data to memory
    .ByteEnable(ByteEnable),             // byte lanes to write (bit 0 = bits [7:0])
    .LoadData(LoadDataM));               // value written back to the register file
```

The data memory writes byte lane *i* of `WriteData` only when `ByteEnable[i]` is 1, and returns
the whole aligned word in `ReadData`. The writeback mux selects `LoadData` for loads.

## Coding rules (all agents)

- SystemVerilog-2012 subset accepted by **Icarus Verilog 12** (`iverilog -g2012`) **and** by Yosys
  (ORFS synthesis). Use `logic`, `always_comb`, `case`. No `initial` blocks, no delays, no
  `$display` in RTL, no SystemVerilog `interface`/`class`/`unique case`/`priority`.
- Purely combinational: no clock, no reset, no state. Every output must be assigned on every path
  (assign defaults at the top of `always_comb`) so synthesis infers no latches.
- One module only, in `workspace/src/memory_access.sv`.
- Little-endian; only naturally aligned accesses are tested (spec "Alignment Scope").
