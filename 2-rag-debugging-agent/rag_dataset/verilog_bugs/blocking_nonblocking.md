# Bug: blocking vs. non-blocking assignment misuse

**Symptom:** Registers update in the wrong order, or a value is "one cycle late",
or simulation and synthesis disagree.

**Rule of thumb:**
- Use **non-blocking** (`<=`) for sequential logic inside `always @(posedge clk)`.
- Use **blocking** (`=`) for combinational logic inside `always @(*)`.

```verilog
always @(posedge clk) q <= d;      // sequential: non-blocking
always @(*)           y = a & b;   // combinational: blocking
```

Mixing them (e.g. blocking assignments to a flip-flop) is a common source of
race-like mismatches between simulation results.
