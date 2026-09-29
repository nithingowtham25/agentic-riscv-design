# Common Icarus Verilog messages and what they mean

- **`error: Unable to bind wire/reg/memory 'xyz'`** — a signal is used but never
  declared (typo, or missing port). Declare it, or fix the name.

- **`error: Unknown module type: foo`** — you instantiated module `foo` but its
  source file was not passed to `iverilog`. Add the file to the compile command.

- **`warning: implicit definition of wire 'sig'`** — you used `sig` without
  declaring it; Verilog auto-created a 1-bit wire. Usually a bug if you expected a bus.

- **`error: reg 'x' is not a valid l-value ...`** — assigning to `x` in the wrong
  context (e.g. assigning a `wire` inside `always`, or a `reg` with `assign`).

- **Simulation hangs / times out** — usually a missing `$finish`, or a combinational
  loop, or a clock that never toggles in the testbench.
