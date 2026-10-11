"""Self-mutation validation for the test suite emitted by run_agent.py."""
from __future__ import annotations
import argparse, json, shutil
from pathlib import Path
from run_agent import run_harness


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"mutation anchor not found: {old}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--core", required=True)
    a = p.parse_args()
    out, core = Path(a.out).resolve(), Path(a.core).resolve()
    tests = out / "tests"
    if not list(tests.glob("*.hex")):
        raise SystemExit("No generated tests found; run agent/run_agent.py first.")
    mutations = {
        "forward_a_disabled": ("ForwardAE = 2'b10;", "ForwardAE = 2'b00;"),
        "x0_forward_enabled": ("(RdM != 5'b0) && (RdM == Rs1E)", "(RdM == Rs1E)"),
        "load_use_stall_removed": ("assign LoadUseHazard = (ResultSrcE == 3'b001) && (RdE != 5'b0) &&\n                          ((RdE == Rs1D) || (RdE == Rs2D));", "assign LoadUseHazard = 1'b0;"),
        "redirect_removed": ("assign RedirectE = PCSrcE;", "assign RedirectE = 1'b0;"),
        "target_offset": ("RedirectE ? RedirectTargetE : PCPlus4F", "RedirectE ? (RedirectTargetE + 32'd4) : PCPlus4F"),
    }
    root = out / "self_mutation"
    if root.exists(): shutil.rmtree(root)
    records = []
    for name, (old, new) in mutations.items():
        mutated = root / name / "core"
        shutil.copytree(core, mutated)
        replace_once(mutated / "datapath_pipelined.sv", old, new)
        result = run_harness(root / name, mutated, tests)
        detected = "[FAIL]" in result["output"] or "COMPILE_ERROR" in result["output"] or "TIMEOUT" in result["output"]
        records.append({"mutation": name, "detected": detected, "result": result})
        print(f"{name}: {'DETECTED' if detected else 'NOT DETECTED'}")
    (out / "run_records" / "self_mutation.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    return 0 if all(x["detected"] for x in records) else 1

if __name__ == "__main__":
    raise SystemExit(main())