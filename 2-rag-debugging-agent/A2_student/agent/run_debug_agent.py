"""run_debug_agent.py: Driver that runs the Debugging Agent on one module  using one of the 3 arms (Baseline / RAG / RAG+feedback).
run_debug_agent.py: Wires the spec, the LLM client, the RAG retriever, and the module's Icarus test together.

Run from the package root, e.g.:
    python -m rag.build_index --dataset rag_dataset --index-dir .rag_index
    python agent/run_debug_agent.py --module pc_unit --arm rag_feedback --provider tamu

The 3 unit modules (pc_unit, branch_unit, memory_access) each have a standalone testbench.
The `datapath` target has no standalone test. It is exercised by running every sample program
through the integrated core (all eight modules), so its loop uses scripts/run_datapath_all.sh.
"""
import argparse
import json
import sys
from pathlib import Path

# Package root + agent dir on the path so bare imports in the agent modules resolve.
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "agent"))

from iterative_rtl_agent import run_experiment
from llm_clients import build_llm_client
from rag.rag_retriever import IndexRetriever

ARMS = {
    "baseline":     dict(use_rag=False, use_feedback=False),
    "rag":          dict(use_rag=True,  use_feedback=False),
    "rag_feedback": dict(use_rag=True,  use_feedback=True),
}

SYSTEM = (
    "You are an expert RTL engineer. Output ONE synthesizable SystemVerilog module and nothing "
    "else - no explanation, no markdown fences. Match the module name, ports, and behavior in the "
    "specification EXACTLY. Use only the low bits required for indexing; keep results the declared width."
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", required=True,
                    choices=["pc_unit", "branch_unit", "memory_access", "datapath"])
    ap.add_argument("--arm", default="rag_feedback", choices=list(ARMS))
    ap.add_argument("--provider", choices=["tamu", "openai"], default=None)
    ap.add_argument("--model", default="gpt-5.4")
    ap.add_argument("--index-dir", default=".rag_index")
    ap.add_argument("--log-file", default=None,
                    help="Write the full run record (arm, module, provider/model, per-iteration log, "
                         "retrievals, final status) to this JSON file, for your Task 2-4 hand-in.")
    ap.add_argument("--seed-rtl", default=None,
                    help="Start the loop from this RTL file (used for the repair demo): the first "
                         "iteration tests the provided file as-is, so a known-broken seed makes "
                         "iteration 0 fail and the feedback loop repair it in later iterations.")
    args = ap.parse_args()

    module = args.module
    spec_text = (ROOT / "specs" / f"{module}_spec.md").read_text()
    rtl_path = ROOT / "rtl" / f"{module}.sv"
    if module == "datapath":
        # datapath has no standalone unit test: exercise it with every sample program through
        # the integrated core. The runner discovers all eight modules in rtl/ itself.
        run_argv = ["bash", str(ROOT / "scripts" / "run_datapath_all.sh")]
        # The port lists of the seven modules the datapath must instantiate are supplied through the
        # RAG knowledge base (rag_dataset/module_specs/module_interfaces.md), so retrieval (not a
        # hardcoded prompt) is what tells the model the real interfaces. This makes the ablation
        # meaningful: without RAG the model must guess the ports (baseline arm).
    else:
        run_argv = ["bash", str(ROOT / "scripts" / f"run_{module}.sh"), str(rtl_path)]

    client = build_llm_client(args.model, provider=args.provider)

    # Optional repair-demo seed: on the FIRST generation, return this broken RTL verbatim instead of
    # calling the LLM, so iteration 0 tests (and fails on) a known-bad design. Later iterations use
    # the real LLM with the tool feedback, so the feedback loop is what fixes it.
    seed_text = None
    if args.seed_rtl:
        seed_path = Path(args.seed_rtl)
        if not seed_path.is_file():
            sys.exit(f"--seed-rtl file not found: {args.seed_rtl} "
                     f"(the seeded bugs live in bugs/, e.g. bugs/{module}_buggy.sv)")
        seed_text = seed_path.read_text()
    seed_state = {"used": False}

    def llm_call(conversation):
        if seed_text is not None and not seed_state["used"]:
            seed_state["used"] = True
            return seed_text
        # Build one focused single-turn prompt for the simple chat client: the original task
        # (spec + any retrieved context, always conversation[0]) plus, if this is a repair, only
        # the CURRENT candidate and the LATEST tool feedback. Older feedback/attempts are dropped so
        # each repair works on the current RTL against its own failure, and the prompt does not grow
        # unboundedly across iterations.
        user_msgs = [m["content"] for m in conversation if m["role"] == "user"]
        assistant_prior = [m["content"] for m in conversation if m["role"] == "assistant"]
        user = user_msgs[0]
        if assistant_prior:
            user += "\n\nYOUR CURRENT RTL (revise this):\n" + assistant_prior[-1]
            user += "\n\nLATEST TOOL FEEDBACK:\n" + user_msgs[-1]
        from io_utils import strip_markdown_code_blocks
        return strip_markdown_code_blocks(client.generate(user, system_prompt=SYSTEM))

    retriever = None
    if ARMS[args.arm]["use_rag"]:
        retriever = IndexRetriever.load(args.index_dir)

    print(f"=== module={module} arm={args.arm} provider={client.provider} ===")
    result = run_experiment(
        spec_text=spec_text,
        initial_prompt=f"Implement the `{module}` module for a single-cycle RV32I processor.",
        rtl_path=str(rtl_path),
        run_command_argv=run_argv,
        llm_call=llm_call,
        retriever=retriever,
        top_k=5,
        **ARMS[args.arm],
    )
    print("iterations:")
    for it in result["iterations"]:
        print("  ", it)
    print("final_status:", result["final_status"])
    print("retrievals:", result["retrievals"])

    if args.log_file:
        # Save a self-contained run record for the Tasks. The retrieval log is stored
        # exactly as your Phase B produced it (default=str keeps it JSON-safe whatever you logged).
        record = {
            "module": module,
            "arm": args.arm,
            "provider": client.provider,
            "model": args.model,
            "seed_rtl": args.seed_rtl,
            "iterations": result["iterations"],
            "retrievals": result["retrievals"],
            "final_status": result["final_status"],
        }
        log_path = Path(args.log_file)
        if log_path.parent != Path(""):
            log_path.parent.mkdir(parents=True, exist_ok=True)  # create logs/ if it doesn't exist yet
        log_path.write_text(json.dumps(record, indent=2, default=str) + "\n")
        print("log written:", args.log_file)
    return 0 if result["final_status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
