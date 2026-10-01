# Bug: unsigned comparison used where signed is required (e.g. RISC-V SLT)

**Symptom:** `SLT` / signed-less-than gives wrong result for negative operands
(e.g. -1 < 1 returns 0 instead of 1).

**Cause:** In Verilog, `<` on plain `reg`/`wire [31:0]` operands is *unsigned*.
A negative two's-complement value has a large unsigned magnitude, so the compare is wrong.

**Fix:** Compare as signed. Either declare signed nets, or cast:

```verilog
result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;   // SLT
result = (a < b) ? 32'd1 : 32'd0;                      // SLTU (unsigned) stays as-is
```
