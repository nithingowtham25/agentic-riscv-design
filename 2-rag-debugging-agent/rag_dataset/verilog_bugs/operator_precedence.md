# Bug: operator precedence / logical-vs-bitwise confusion

**Symptom:** a condition or result is subtly wrong — e.g. a branch taken at the wrong
time, or a combined signal that's off.

**Cause:**
- Bitwise (`&`, `|`, `^`) vs logical (`&&`, `||`, `!`) operators used interchangeably.
- Missing parentheses: `a & b == c` parses as `a & (b == c)` because `==` binds tighter
  than `&`.
- Reduction operators (`&a`, `|a`, `^a`) confused with binary ones.

**Fix:** parenthesize explicitly and use the intended operator class.

```verilog
if ((a & mask) == expected) ...   // not:  if (a & mask == expected)
assign taken = zero || jump;      // logical OR of 1-bit control signals
```
