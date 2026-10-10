# Required invariants (Task 4)

Your `results/assertions.sv` (module `student_assertions`) must formalize these invariants of the
pipelined core. Each must hold on **every** cycle of a correct run, so a correct core never triggers them.
Write them as immediate assertions in a clocked block; print a line starting with `ASSERT_FAIL <name>` on
a violation. The template `harness/assertions_template.sv` gives you the exact ports.

1. **x0 reads as zero.** When a Decode-stage source address is `x0` (`Rs1D == 0` or `Rs2D == 0`), the
   value read for that port (`rd1D` / `rd2D`) must be 0. A broken read path that returns something else
   violates the hardwired-zero guarantee.

2. **No forwarding into x0.** If an Execute-stage source operand is register `x0`
   (`Rs1E == 0` or `Rs2E == 0`), forwarding for that operand must be disabled (`ForwardAE`/`ForwardBE`
   is `00`). x0 always reads 0, so forwarding a producer into it would inject a nonzero value.

3. **No spurious forwarding.** If forwarding is enabled for an operand, a real in-flight producer must
   exist for that exact register: `ForwardAE == 10` (Memory stage) requires
   `RegWriteM && RdM == Rs1E && RdM != 0`; `ForwardAE == 01` (Writeback stage) requires
   `RegWriteW && RdW == Rs1E && RdW != 0`; and symmetrically for `ForwardBE` with `Rs2E`. A forwarding
   unit that forwards when no matching producer is in flight violates this.

You may add more of your own invariants - additional correct assertions can only help, as long as they
stay silent on your correct core.

**Tip:** develop assertions against your correct core first (they must never fire), then reason about which
bug each invariant would catch. An assertion that fires on the correct core is a false positive and
scores 0 for Task 4.
