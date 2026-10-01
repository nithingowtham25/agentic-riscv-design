# Bug: incomplete sensitivity list / accidental latch

**Symptom:** combinational output is stale (doesn't update when an input changes), or
synthesis infers an unintended latch. Simulation and synthesis may disagree.

**Cause:** an `always` block meant to be combinational lists only some inputs
(`always @(a)` instead of `always @(*)`), or a `case`/`if` that doesn't assign the output
on every path (so it "remembers" its old value).

**Fix:** use `always @(*)` for combinational logic, and assign the output on every branch
(add a `default`, or a leading default assignment).

```verilog
always @(*) begin
    y = 0;               // default avoids a latch
    case (sel) 2'b01: y = a; 2'b10: y = b; endcase
end
```
