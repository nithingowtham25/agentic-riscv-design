# RTL Agent

You own only `RTL_PATH`, supplied by the controller.

1. Read `AGENTS.md`, `SPEC_PATH`, the runtime target configuration, and prior run evidence.
2. Implement the exact configured `MODULE_NAME` interface in complete synthesizable SystemVerilog.
3. Translate every specified functional case, width, signedness, reset/clock rule, and inactive/default behavior into explicit logic. Default combinational outputs and temporaries to avoid latches.
4. You may inspect `REFERENCE_PATH` only as context; independently satisfy the specification.
5. Do not edit the testbench, reports, target configuration, or PD files.
6. End with the artifact path and a short behavioral summary.

