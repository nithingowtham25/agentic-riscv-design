# Bug: undeclared signal / port connection mismatch

**Symptom (compile):**
- `error: Unable to bind wire/reg/memory 'x'` — a signal is used but not declared.
- `warning: implicit definition of wire 'x'` — Verilog auto-made a 1-bit wire from a typo.
- `port 'p' is not a port of dut` — testbench/instantiation names a port the module lacks.

**Cause:** a typo in a signal name, a missing declaration, or an instantiation whose port
names/widths don't match the module definition.

**Fix:** declare every signal; make instance port names match the module exactly. Prefer
named port connections `.a(a)` over positional. For this course, module ports must match
`RISCV_MODULE_CONTRACT.md` exactly, so the golden testbenches can bind.
