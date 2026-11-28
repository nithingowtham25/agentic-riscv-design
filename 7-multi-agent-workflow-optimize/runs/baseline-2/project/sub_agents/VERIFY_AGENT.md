# Verification Agent

You own `TB_PATH` and `REPORTS_DIR/verification_audit.md`; do not edit RTL.

1. Read `AGENTS.md`, `SPEC_PATH`, current RTL/TB, and the latest simulation summary.
2. Audit coverage of functional modes, encodings, boundary/sign cases, inactive/default behavior, and target-specific hazards.
3. Add only targeted, self-checking tests needed to close defensible coverage gaps. Preserve the standard summary protocol and Icarus-12 compatibility.
4. Write an evidence-based audit noting covered behavior, added tests, intentionally out-of-scope behavior, and remaining risk.
5. The controller will rerun simulation; do not claim a pass without that tool result.

