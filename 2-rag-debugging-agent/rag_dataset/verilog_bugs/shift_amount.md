# Bug: shift by full operand instead of low 5 bits; logical vs arithmetic shift

**Symptom:** shift results are wrong for large shift amounts, or right shifts of negative
numbers don't sign-extend (SRA behaves like SRL).

**Cause (RV32I):**
- The shift amount must be only the **low 5 bits** of the operand: `b[4:0]`. Using the full
  32-bit `b` gives huge/zeroed results.
- **SRL** (logical) zero-fills; **SRA** (arithmetic) sign-extends. SRA requires a signed
  operand or `>>>` on `$signed(...)`.

**Fix:**
```verilog
alu_out = a << b[4:0];              // SLL
alu_out = a >> b[4:0];             // SRL (logical)
alu_out = $signed(a) >>> b[4:0];   // SRA (arithmetic)
```
