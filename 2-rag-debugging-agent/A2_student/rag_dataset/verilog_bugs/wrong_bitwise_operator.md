# Bug: wrong bitwise operator in the ALU (e.g. XOR coded as AND)

**Symptom:** one ALU operation returns the wrong result while the others are fine —
for example the XOR case returns `a & b` instead of `a ^ b`, so `0xAA ^ 0x55` gives
`0x00` instead of `0xFF`.

**Cause:** the wrong Verilog bitwise operator was used for that opcode:
`&` (AND), `|` (OR), `^` (XOR), `~` (NOT) are easy to mix up.

**Fix:** use the correct operator for the operation. For XOR:

```verilog
alu_out <= a ^ b;   // XOR (not a & b)
```

RV32I bitwise ops: AND = `a & b`, OR = `a | b`, XOR = `a ^ b`.
