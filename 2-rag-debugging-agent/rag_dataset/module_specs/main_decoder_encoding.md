# Project-specific main_decoder control word (THIS core)

`main_decoder` drives a packed 16-bit `controls` bus, unpacked in this exact field order:

```
{RegWrite, ImmSrc[2:0], ALUSrc, MemWrite, ResultSrc[1:0], Branch[2:0], ALUOp[1:0], Jump, Jalr, unsign}
```

Per-opcode `controls` values used in this design (from op = instr[6:0]):

| Instr | op | controls (16b) |
|-------|-----|----------------|
| lw    | 0000011 | `1_000_1_0_01_000_00_0_0_0` |
| sw    | 0100011 | `0_001_1_1_00_000_00_0_0_0` |
| R-type| 0110011 | `1_xxx_0_0_00_000_10_0_0_0` |
| I-ALU | 0010011 | `1_000_1_0_00_000_10_0_0_0` (shift: ImmSrc=101; unsigned: unsign=1) |
| jal   | 1101111 | `1_011_0_0_10_000_00_1_0_0` |
| jalr  | 1100111 | `1_000_1_0_10_000_00_1_1_0` |
| lui   | 0110111 | `1_100_1_0_00_000_00_0_0_0` |
| auipc | 0010111 | `1_100_1_0_11_000_00_0_0_0` |

**Branch[2:0] codes (project-specific, set for op=1100011 by funct3):**
beq=`100`, bne=`101`, blt=`110`, bge=`111`, bltu=`001`, bgeu=`011`.

**ImmSrc[2:0]:** I=000, S=001, B=010, J=011, U=100, shift-uimm=101.
**ResultSrc[1:0]:** ALU=00, mem=01, PC+4=10, imm/upper=11.

Common bug: wrong field order in the unpack, or a wrong per-opcode value (e.g. ALUSrc/
MemWrite swapped). The unpack order above is fixed for this core.
