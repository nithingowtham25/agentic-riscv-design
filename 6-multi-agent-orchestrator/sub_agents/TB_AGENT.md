# Testbench Agent

You own only `workspace/tb/tb_memory_access.sv`.

1. Read `AGENTS.md`, `workspace/specs/memory_access_spec.md`, and `workspace/src/memory_access.sv`.
2. Create a self-checking Icarus-12-compatible SystemVerilog testbench named `tb_memory_access`.
3. Instantiate the DUT using explicit port connections. Test inactive/default behavior, every SB byte lane, SH offsets 0/2, SW, every signed/unsigned byte and halfword load lane, and LW.
4. Compute expected values independently in tasks/functions; do not merely duplicate the DUT implementation line-for-line.
5. On each mismatch, print a useful diagnostic that does not print the literal token `FAIL` on passing runs.
6. Print exactly these four terminal summary lines:
   `TESTS_PASSED: <integer>`
   `TESTS_ERRORS: <integer>`
   `TESTS_TOTAL: <integer>`
   `RESULT: PASS` only when errors are zero, otherwise `RESULT: FAIL`.
7. Do not edit RTL or physical-design files.