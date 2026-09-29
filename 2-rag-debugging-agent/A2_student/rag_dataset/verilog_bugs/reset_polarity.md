# Bug: wrong reset polarity or missing reset in a flip-flop

**Symptom:** registers never clear (or clear when they shouldn't); the design starts in
`x` or a wrong state and never recovers.

**Cause:** reset tested with the wrong polarity (`if (!rst)` when reset is active-high),
reset left out of the sensitivity list for an async reset, or the reset branch assigning
the wrong value.

**Fix:** match the intended polarity and, for async reset, include it in the sensitivity
list. For this core, `reset_ff` uses **active-high async reset**:

```verilog
always @(posedge clk or posedge rst)
    if (rst) q <= 0;      // active-high: clear when rst==1
    else     q <= d;
```
