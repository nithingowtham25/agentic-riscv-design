# RV32I immediate encodings (exact bit layout)

The immediate bits are scrambled differently for each instruction format. `instr` is the
32-bit instruction; the sign bit is always `instr[31]`. Exact layouts:

- **I-type** (`addi`, `lw`, `jalr`): `imm = {sext(instr[31]), instr[31:20]}`
- **S-type** (stores): `imm = {sext(instr[31]), instr[31:25], instr[11:7]}`
- **B-type** (branches, `beq`/`bne`/...): the tricky one —
  `imm = {sext(instr[31]), instr[7], instr[30:25], instr[11:8], 1'b0}`
  Note the order: **bit 12 = instr[31], bit 11 = instr[7], bits 10:5 = instr[30:25],
  bits 4:1 = instr[11:8], bit 0 = 0.** `instr[7]` supplies bit 11 (NOT the low bits),
  and the least-significant bit is always 0 (2-byte aligned).
- **J-type** (`jal`): `imm = {sext(instr[31]), instr[19:12], instr[20], instr[30:21], 1'b0}`
- **U-type** (`lui`, `auipc`): `imm = {instr[31:12], 12'b0}`

Common mistake: for B-type, placing `instr[7]` at the low end or keeping the fields in
"natural" order. The correct Verilog is:

```verilog
// B-type
immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
```
