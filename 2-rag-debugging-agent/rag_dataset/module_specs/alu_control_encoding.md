# Project-specific ALU control encoding (THIS core)

The `alu_decoder` maps `funct3` to a 3-bit `ALUControl` code that the `alu` module
consumes. **This encoding is specific to this design** and does NOT follow any external
convention — use exactly these codes:

| Operation | ALUControl |
|-----------|-----------|
| ADD | `3'b000` |
| SUB | `3'b001` |
| AND | `3'b010` |
| OR  | `3'b011` |
| XOR | `3'b100` |
| SLT | `3'b101` |
| **SLL** | **`3'b110`** |
| **SRL / SRA** | **`3'b111`** |

`funct3` → `ALUControl` for R/I-type:
`000`→ADD/SUB, `001`→SLL(`110`), `010`→SLT(`101`), `100`→XOR(`100`),
`101`→SRL/SRA(`111`), `110`→OR(`011`), `111`→AND(`010`).

Note the shifts: **SLL is `110` and SRL/SRA is `111`** in this core — not any other value.
The `alu` module decodes these exact codes, so the decoder must match them.
