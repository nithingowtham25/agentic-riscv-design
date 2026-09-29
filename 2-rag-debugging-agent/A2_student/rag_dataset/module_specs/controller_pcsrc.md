# Project-specific controller PCSrc / branch logic (THIS core)

`controller` instantiates `main_decoder` and `alu_decoder`, then computes `PCSrc`
(take-branch/jump) from the `Branch[2:0]` code, `Zero` (ALU result == 0), `CmpResult`
(signed/unsigned less-than from the ALU), and `Jump`:

```verilog
case (Branch)
    3'b100: PCSrc = Zero      | Jump;   // beq  : taken when equal
    3'b101: PCSrc = ~Zero     | Jump;   // bne  : taken when not equal
    3'b110: PCSrc = CmpResult | Jump;   // blt  : taken when a <  b
    3'b111: PCSrc = ~CmpResult | Zero | Jump; // bge : taken when a >= b
    3'b001: PCSrc = CmpResult | Jump;   // bltu
    3'b011: PCSrc = ~CmpResult | Jump;  // bgeu
    default: PCSrc = Jump;              // jal, jalr, non-branch
endcase
```

Notes specific to this core:
- `bge` uses `~CmpResult | Zero` (greater-OR-equal must also fire on equality).
- The `Branch` codes are the project-specific values from `main_decoder` (beq=100 …),
  not any external convention.
- Non-branch instructions fall through to `default`, so `PCSrc = Jump`.

Common bug: mixing up `Zero`/`~Zero` (beq vs bne) or dropping the `| Zero` term in `bge`.
