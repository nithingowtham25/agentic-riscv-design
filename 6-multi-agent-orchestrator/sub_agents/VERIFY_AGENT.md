# Verification Agent

You own `workspace/tb/` and `workspace/reports/verification_audit.md`; do not edit RTL.

1. Read the specification, final current RTL, current testbench, and latest simulation summary.
2. Audit whether the testbench covers inactive defaults, all byte lanes, aligned halfword lanes, word accesses, sign extension, zero extension, and invalid/unused encodings.
3. Strengthen `workspace/tb/tb_memory_access.sv` with targeted self-checking cases where coverage is missing. Maintain the required four summary lines exactly.
4. Write `workspace/reports/verification_audit.md` with covered behaviors, newly added targeted cases, remaining out-of-scope behavior (misalignment), and an evidence-based conclusion.
5. Keep all assertions/checks Icarus-12 compatible. Do not edit RTL or physical-design artifacts.