# Tasks 2-4 - Verification Agent, Coverage, Assertions, and Self-Mutation Analysis

## Scope and evidence

This analysis covers two completed runs:

1. The Tasks 2-4 Verification Agent run (`tasks2to4_agent_20261011_005648.log`).
2. The Task 2 self-mutation validation (`task2_self_mutation_20261011_011947.log`).

The persistent structured evidence is retained in `results/run_records/agent_run.json` and `results/run_records/self_mutation.json`. The generated suite, coverage result, and assertions remain in `results/tests/`, `results/coverage.json`, and `results/assertions.sv` respectively.

## Agent configuration and operation

The agent was run with the required TAMU AI Chat provider and model `gpt-5.4`, with a maximum budget of two calls. It used one call because the first coverage-guided expansion closed every published coverage bin; a second request was therefore unnecessary. The provider record reports 78 prompt tokens, 525 completion tokens, and 603 total tokens.

The agent first evaluated a small seed subset consisting of `branch_flush.hex` and `forwarding.hex`. It used the resulting coverage gap as context for its LLM planning request, which recommended directed tests for forwarding, x0 integrity, load-use dependencies, flush/redirect behavior, JAL/JALR targets, and interaction cases. The agent emitted RV32I machine-code programs using the supplied instruction encoders. Every candidate is then evaluated by the supplied simulator and reference ISS; the reference model, not the LLM response, determines whether a test passes.

## Task 2 - Test suite and bug-detection evidence

The final suite contains six programs:

| Test program | Main purpose |
|---|---|
| `forwarding.hex` | Register data dependencies and forwarding paths |
| `load_use_and_memory.hex` | Load-use stall, load data use, and byte memory behavior |
| `x0_integrity.hex` | x0 write suppression and zero readback |
| `branch_flush.hex` | Taken/untaken branch behavior and wrong-path flushing |
| `jumps.hex` | JAL link behavior, JALR redirection, and target alignment |
| `instruction_mix.hex` | LUI, AUIPC, immediate ALU operations, and ordinary pipeline execution |

All six tests passed on the original correct core. The test suite was then validated by self-mutation, using copied cores only. Each injected bug was detected because at least one program failed when its final signature was compared with the reference ISS:

| Injected bug class | Mutation | Failing generated program(s) | Outcome |
|---|---|---|---|
| Forwarding | Disable Memory-stage forwarding for source A | `forwarding.hex`, `instruction_mix.hex`, `x0_integrity.hex` | Detected |
| x0 integrity | Allow a producer with `rd=x0` to forward | `x0_integrity.hex` | Detected |
| Load-use hazard | Remove the load-use stall | `load_use_and_memory.hex` | Detected |
| Flush/redirect | Disable Execute-stage redirect | `branch_flush.hex`, `jumps.hex` | Detected |
| Branch/jump target | Offset every redirect target by one instruction | `branch_flush.hex`, `jumps.hex` | Detected |

Thus, all five required Task 2 bug categories were detected. The mutation script leaves the correct core and the generated test suite unchanged. Its temporary copied cores are under `results/self_mutation/`, while the submit-worthy permanent evidence is `results/run_records/self_mutation.json` plus the terminal log.

## Task 3 - Coverage-driven validation

The initial two-program seed suite covered **13/21 bins (62%)**. The missed bins were `OP_AUIPC`, `OP_JAL`, `OP_JALR`, `OP_LOAD`, `OP_LUI`, `jal`, `jalr`, and `load_use_stall`.

After the targeted suite expansion, all six generated tests passed on the original core and achieved **21/21 bins (100%)**. The exact required file `results/coverage.json` records:

```json
{"before": 62, "after": 100}
```

The full suite closes the gaps with the load/memory program, the branch/flush program, the JAL/JALR program, and the LUI/AUIPC instruction-mix program. Coverage was collected only from passing simulations on the original core, as required.

## Task 4 - Assertion generation

The agent generated `results/assertions.sv` with the required module name `student_assertions` and template-compatible ports. It uses immediate assertions in a clocked block and emits an `ASSERT_FAIL <name>` line upon violation. The assertions formalize the required invariants:

- Decode reads of x0 return zero on both read ports.
- Forwarding is disabled when an Execute operand names x0.
- A Memory-stage forwarding select requires a matching nonzero Memory-stage producer.
- A Writeback-stage forwarding select requires a matching nonzero Writeback-stage producer.

The assertion-enabled harness run completed with all six generated tests passing and no `ASSERT_FAIL` messages. Therefore, the assertion set showed no false positives on the correct core. Whether these assertions catch hidden instructor mutations remains an evaluation-time check, but their required invariants are implemented and their silence on the verified core is demonstrated.

## Final conclusion

The Verification Agent meets the required interface, supports TAMU AI Chat, records provider/model/token evidence, obeys the call limit, emits a reproducible `.hex` suite, measures and closes coverage gaps, produces assertions, and preserves structured evidence. The final test suite passes on the correct core, reaches 100% of the 21 published bins, and detects all five required self-injected bug categories.