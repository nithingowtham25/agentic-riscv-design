"""iterative_rtl_agent.py: The Debugging Agent's automated generate-and-repair loop (YOU build this).

You implement the loop that generates RTL, runs it through the tools, and repairs it on failure, 
optionally using retrieval (RAG) and iterative tool feedback. Three arms share this one function:
  - Baseline:        use_rag=False, use_feedback=False
  - RAG:             use_rag=True,  use_feedback=False
  - RAG + feedback:  use_rag=True,  use_feedback=True

FIXED POLICY (do not change this so that the three arms are compared fairly):
  - at most MAX_REPAIR_ITERATIONS repairs after the initial candidate;
  - stop on the first pass (return code 0);
  - keep-best uses the provided _STATUS_RANK ordering (higher is better).

The repair budget and the status ranking (_STATUS_RANK) are provided and fixed. You fill in:
  - Phase B: the initial prompt + optional retrieval;
  - Phase C: classify_status in tool_feedback.py (pass / compile_error / sim_fail);
  - Phase D: generating and testing a candidate (generate -> write -> run -> record);
  - Phase E: the keep-best bookkeeping (remember the best RTL, and on a worse repair restore it);
  - Phase F: the repair-feedback message.
Do not edit outside the marked phases. (Phase A, the retrieval logic itself, is in rag/index.py.)
"""
from pathlib import Path

from tool_feedback import run_command, compact_feedback   # provided: run a tool cmd -> structured status
from rag.retriever_interface import format_examples       # provided: format retrieved chunks for a prompt

MAX_REPAIR_ITERATIONS = 5

# keep-best ordering (provided and FIXED): higher is better; a sim failure is "closer" to passing
# than a compile error. Use this ranking in Phase D to decide whether a repair improved the result.
_STATUS_RANK = {"compile_error": 0, "sim_fail": 1, "pass": 2}


def _rank(status: str) -> int:
    return _STATUS_RANK.get(status, 0)


def run_experiment(*, spec_text, initial_prompt, rtl_path, run_command_argv, llm_call,
                   retriever=None, use_rag=False, use_feedback=False, top_k=5):
    """Run one generate-and-repair experiment and return its logs.

    Provided to you:
      - llm_call(conversation) -> str : sends the chat conversation to the LLM, returns cleaned RTL text.
      - run_command(argv) -> result   : runs the tool flow; result.status is 'pass'|'sim_fail'|'compile_error',
                                        result.returncode is 0 on pass.
      - retriever.retrieve(query, top_k=k) -> examples ; format_examples(examples) -> str for the prompt.
    """
    conversation = [{"role": "user", "content": initial_prompt + "\n\nSPECIFICATION:\n" + spec_text}]
    retrieval_log = []
    iteration_log = []

    # ------------------------------------------------------------------
    # PHASE B - initial prompt + optional retrieval (RAG)
    # If use_rag is on and a retriever is provided, form a query from the prompt+spec, retrieve the
    # top_k examples, log them (append to retrieval_log), and append the formatted examples to the
    # first user message (conversation[-1]["content"]). Use format_examples(...) to format them.
    #
    # >>> BEGIN STUDENT PHASE B

    # <<< END STUDENT PHASE B

    best_rtl = None
    best_status = None

    for iteration in range(MAX_REPAIR_ITERATIONS + 1):
        # --------------------------------------------------------------
        # PHASE D - generate a candidate and test it
        # Call the LLM on the conversation, save the returned RTL to rtl_path, append it to the
        # conversation as an assistant turn, then run the tool flow. Set `result` to the tool result
        # and append a record to iteration_log with keys: "iteration", "status", "returncode".
        # (The status comes from your classify_status, Phase C, via run_command.)
        #
        # >>> BEGIN STUDENT PHASE D
        result = None  # replace: generate -> write rtl_path -> run_command(...) -> record in iteration_log

        # --------------------------------------------------------------
        # PHASE E - keep-best bookkeeping
        # Track the best-scoring RTL seen so far using _rank(result.status) (higher is better):
        #   - if this candidate is at least as good as the best so far (or it's the first one),
        #     remember it: set best_rtl to the current RTL and best_status to result.status;
        #   - otherwise this repair made things WORSE - restore the previous best_rtl by writing it
        #     back to rtl_path, and mark this iteration_log entry with "kept_best" = True.
        #
        # >>> BEGIN STUDENT PHASE E
        raise NotImplementedError("Implement Phase E keep-best: remember the best RTL, restore it on a worse repair.")
        # <<< END STUDENT PHASE E

        if result.returncode == 0:
            break  # stop on pass (provided)
        if not use_feedback or iteration == MAX_REPAIR_ITERATIONS:
            break  # no feedback loop, or repair budget exhausted (provided)

        # --------------------------------------------------------------
        # PHASE F - feed the tool failure back for the next repair
        # Append a user turn that tells the LLM the design failed and asks for a complete revised
        # module. Include the structured tool feedback via compact_feedback(result).
        #
        # >>> BEGIN STUDENT PHASE F

        # <<< END STUDENT PHASE F

    return {
        "iterations": iteration_log,
        "retrievals": retrieval_log,
        "final_status": best_status,
        "conversation": conversation,
    }
