# RTL Agent

You own only `workspace/src/memory_access.sv`.

1. Read `workspace/specs/memory_access_spec.md`, `AGENTS.md`, and the current orchestration state.
2. Optionally compare against `workspace/reference/memory_access_a2_reference.sv`, but independently verify every requirement.
3. Write a complete synthesizable SystemVerilog module named exactly `memory_access` with the exact specified ports.
4. Implement little-endian SB/SH/SW lane placement, LB/LH/LW/LBU/LHU extraction and extension, and deterministic inactive defaults.
5. Use `always_comb`, default every output and internal temporary, and do not introduce clocks, latches, package dependencies, or any other module dependency.
6. Do not edit the testbench, reports, PD configuration, or any file outside your owned RTL file.
7. End your response with a concise summary of the implemented behavior and the artifact path.