#!/usr/bin/env python3
"""Compile and run one self-checking SystemVerilog testbench in an isolated run."""
from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rtl", required=True); parser.add_argument("--tb", required=True)
    parser.add_argument("--tb-top", required=True); parser.add_argument("--reports", required=True)
    args = parser.parse_args()
    rtl, tb, reports = Path(args.rtl).resolve(), Path(args.tb).resolve(), Path(args.reports).resolve()
    reports.mkdir(parents=True, exist_ok=True)
    log, summary, sim_bin = reports / "sim_output.log", reports / "sim_summary.json", reports / "sim.out"
    data: dict[str, object] = {"timestamp": datetime.now(timezone.utc).isoformat(), "rtl": str(rtl), "tb": str(tb), "tb_top": args.tb_top}
    if not rtl.is_file() or not tb.is_file():
        missing = [str(path) for path in (rtl, tb) if not path.is_file()]
        data.update({"status": "FAIL", "reason": "missing_artifact", "missing": missing})
        log.write_text("ERROR: Missing required artifact(s): " + ", ".join(missing) + "\n", encoding="utf-8")
        summary.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8"); print("SIMULATION FAIL: missing artifact"); return 1
    compile_result = subprocess.run(["iverilog", "-g2012", "-s", args.tb_top, "-o", str(sim_bin), str(rtl), str(tb)], capture_output=True, text=True, check=False)
    transcript = ["=== Icarus compile ===", "$ " + " ".join(map(str, compile_result.args)), compile_result.stdout, compile_result.stderr]
    data["compile_returncode"] = compile_result.returncode
    if compile_result.returncode:
        data.update({"status": "FAIL", "reason": "compile_error"}); transcript.append("RESULT: FAIL")
        log.write_text("\n".join(transcript), encoding="utf-8"); summary.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print("SIMULATION FAIL: compilation error"); return 1
    sim_result = subprocess.run(["vvp", str(sim_bin)], capture_output=True, text=True, check=False)
    transcript += ["=== VVP simulation ===", "$ " + " ".join(map(str, sim_result.args)), sim_result.stdout, sim_result.stderr]
    passed, failed = "RESULT: PASS" in sim_result.stdout, "RESULT: FAIL" in sim_result.stdout
    ok = sim_result.returncode == 0 and passed and not failed
    data.update({"simulation_returncode": sim_result.returncode, "passed_marker": passed, "failed_marker": failed, "status": "PASS" if ok else "FAIL"})
    log.write_text("\n".join(transcript), encoding="utf-8"); summary.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print("SIMULATION SUCCESS" if ok else f"SIMULATION FAIL; inspect {log}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
