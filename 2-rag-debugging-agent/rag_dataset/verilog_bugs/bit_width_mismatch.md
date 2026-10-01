# Bug: bit-width mismatch / truncation

**Symptom:** high bits are lost, a value wraps unexpectedly, or a wide result is silently
truncated into a narrower net. Simulation shows a value that looks "chopped."

**Cause:** an assignment or port connection where the two sides have different widths, or
a literal without an explicit width. Verilog silently truncates/zero-extends to the LHS width.

**Fix:** make widths match explicitly. Size literals (`32'd1`, not `1` when width matters),
declare intermediate nets at full width, and check port widths at instantiation.

```verilog
wire [31:0] sum = a + b;   // ok: full width
wire [7:0]  t   = a + b;   // BUG if a,b are 32-bit: top 24 bits dropped
```
