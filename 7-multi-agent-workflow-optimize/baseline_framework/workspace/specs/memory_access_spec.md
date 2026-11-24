# Assignment 2 Module Specification: `memory_access`

## Purpose

`memory_access` implements the data-formatting portion of a small RV32I load/store unit. It converts register store data into a 32-bit memory write plus byte enables and converts a 32-bit memory read into the value written back to the register file.

The course assumes a **little-endian**, 32-bit data-memory interface.

## Required Interface

```systemverilog
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

## `MemRW`

The encoding is inherited from the Assignment 1 controller:

| `MemRW` | Meaning |
|---|---|
| `00` | no data-memory access |
| `01` | store/write |
| `10` | load/read |
| `11` | unused |

## Supported Store Formats

For stores, `Funct3` is:

| `Funct3` | Operation |
|---|---|
| `000` | SB |
| `001` | SH |
| `010` | SW |

`ByteEnable[3:0]` selects byte lanes of the 32-bit memory word, where bit 0 corresponds to the least-significant byte.

Examples:

- `SB` at byte offset 0: `ByteEnable=0001`, byte placed in `WriteData[7:0]`.
- `SB` at byte offset 2: `ByteEnable=0100`, byte placed in `WriteData[23:16]`.
- `SH` at offset 0: `ByteEnable=0011`.
- `SH` at offset 2: `ByteEnable=1100`.
- `SW` at offset 0: `ByteEnable=1111` and `WriteData=StoreData`.

## Supported Load Formats

For loads, `Funct3` is:

| `Funct3` | Operation | Extension |
|---|---|---|
| `000` | LB  | sign extend selected byte |
| `001` | LH  | sign extend selected halfword |
| `010` | LW  | full 32-bit word |
| `100` | LBU | zero extend selected byte |
| `101` | LHU | zero extend selected halfword |

`AddrLSB` selects the addressed byte/halfword within `ReadData`.

## Alignment Scope

Assignment 2 tests only naturally aligned accesses:

- byte: offsets 0,1,2,3;
- halfword: offsets 0 or 2;
- word: offset 0.

Misaligned halfword/word accesses and architectural misalignment traps are outside the Assignment 2 scope.

## Deterministic Defaults

- When `MemRW != 01`, set `ByteEnable=0000` and `WriteData=0`.
- When `MemRW != 10`, set `LoadData=0`.

These defaults simplify testing and integration.
