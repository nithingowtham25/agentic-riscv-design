# Task 2 Debugging Agent Implementation and End-to-End Smoke Run

## Submitted implementation

Task 2 is implemented in the marked student-code regions of:

- `agent/tool_feedback.py`: Phase C status classification.
- `agent/iterative_rtl_agent.py`: Phase B retrieval/prompt construction, Phase D candidate generation and tool execution, Phase E keep-best handling, and Phase F repair-feedback construction.

The complete smoke-test run record is `logs/pc_unit_smoke.json`.

## End-to-end smoke-test result

The debugging agent was run on `pc_unit` with the `rag_feedback` arm, provider `tamu`, and model `gpt-5.4`. The record contains one retrieval operation with `top_k=5` and one tool iteration.

Iteration 0 generated the initial RTL candidate and the supplied Icarus/unit-test flow returned status `pass` with return code 0. The captured tool feedback reports `Passed: 30 Failed: 0 Total: 30` followed by `>>> RESULT: PASS`. The final status is therefore `pass`; no repair calls were needed. This validates the complete generate -> write RTL -> execute tool flow -> classify result -> log result path. It does not exercise a repair in this particular run because the fixed stop-on-pass policy correctly ends the run at iteration 0. The seeded-bug runs in Task 3 provide the required evidence for the iterative repair path.

## Phase B - Initial prompt and optional RAG context

Phase B begins with the module-specific initial prompt and the supplied specification. For the `rag` and `rag_feedback` arms, it forms a retrieval query from that prompt and specification, requests the configured top-k examples, stores the query and returned chunks in the JSON retrieval log, and appends formatted retrieved context to the first user message. The retrieval record for this smoke run includes module-interface, PCSrc/control-flow, datapath-integration, and sequential-assignment guidance. Retrieved material is supplemental context; the supplied module specification remains the authority when information differs or is incomplete.

## Phase C - Tool-status classification

Phase C maps the supplied tool execution result into exactly one structured status. A zero return code is `pass`. A nonzero return code with compiler/elaboration markers such as `syntax error`, `error:`, `Unable to bind`, `Unknown module type`, or `elaboration failed` is `compile_error`. All other nonzero outcomes are `sim_fail`, meaning compilation completed but the functional test flow failed. This distinction lets the repair loop and keep-best policy compare candidates consistently.

## Phase D - Candidate generation, execution, and logging

For each iteration, Phase D calls the LLM using the current conversation, writes the candidate RTL to the required `rtl/<module>.sv` path, records that candidate as the latest assistant message, and runs the provided command unchanged. It appends an iteration record containing the iteration number, structured status, return code, and compact tool feedback. The Task 2 smoke run demonstrates this phase with iteration 0 and the successful 30/30 `pc_unit` result.

## Phase E - Keep-best policy

Phase E compares each result with the fixed `_STATUS_RANK` ordering: `compile_error` < `sim_fail` < `pass`. The first candidate becomes the current best. A candidate that is at least as good as the best result replaces the best; a worse candidate is discarded and the previous best RTL is rewritten to `rtl/<module>.sv`. The conversation is also restored to that best RTL before the next repair. This prevents a later repair from degrading the best design observed so far. In the smoke run, iteration 0 became the best candidate and `kept_best` is `false`, because no rollback was necessary.

## Phase F - Iterative feedback repair

If the tool result is not `pass`, feedback is enabled, and the five-repair budget has not been exhausted, Phase F appends a repair request to the conversation. The request includes the best/current RTL and compact structured tool feedback containing the status, return code, and relevant simulator output. It instructs the model to return a complete corrected module while preserving the exact interface and specification-conformant behavior. The next iteration then performs Phase D again on that repair candidate.

## Fixed repair policy

The policy is identical for every experimental arm. The initial candidate is iteration 0, and the loop permits at most five additional repair iterations (`MAX_REPAIR_ITERATIONS = 5`). It stops immediately on the first passing tool result. The `baseline` and `rag` arms disable iterative feedback, so they execute only iteration 0; `rag_feedback` enables both retrieval and repair feedback. The provided status ranking is not changed, and Phase E restores the previous best RTL whenever a repair worsens the observed tool status. Together, these constraints make the Baseline, RAG, and RAG+feedback ablation comparison fair and prevent the repair loop from retaining a degraded candidate.