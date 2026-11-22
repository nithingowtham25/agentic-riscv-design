#!/usr/bin/env python3
"""Compile and run the Assignment 6 self-checking memory_access testbench."""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "workspace/src/memory_access.sv"
TB = ROOT / "workspace/tb/tb_memory_access.sv"
REPORTS = ROOT / "workspace/reports"
SIM_BIN = REPORTS / "sim.out"
LOG = REPORTS / "sim_output.log"
SUMMARY = REPORTS / "sim_summary.json"


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    summary: dict[str, object] = {"timestamp": datetime.now(timezone.utc).isoformat(), "rtl": str(RTL.relative_to(ROOT)), "tb": str(TB.relative_to(ROOT))}
    if not RTL.is_file() or not TB.is_file():
        missing = [str(p.relative_to(ROOT)) for p in (RTL, TB) if not p.is_file()]
        message = "ERROR: Missing required artifact(s): " + ", ".join(missing) + "\n"
        LOG.write_text(message, encoding="utf-8")
        summary.update({"status": "FAIL", "reason": message.strip()})
        SUMMARY.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        print(message, end="")
        return 1

    compile_result = run(["iverilog", "-g2012", "-s", "tb_memory_access", "-o", str(SIM_BIN), str(RTL), str(TB)])
    transcript = ["=== Icarus compile ===", "$ " + " ".join(compile_result.args), compile_result.stdout, compile_result.stderr]
    summary["compile_returncode"] = compile_result.returncode
    if compile_result.returncode != 0:
        transcript.append("RESULT: FAIL\n")
        LOG.write_text("\n".join(transcript), encoding="utf-8")
        summary.update({"status": "FAIL", "reason": "compile_error"})
        SUMMARY.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        print("SIMULATION FAIL: compilation error")
        return 1

    sim_result = run(["vvp", str(SIM_BIN)])
    transcript.extend(["=== VVP simulation ===", "$ " + " ".join(sim_result.args), sim_result.stdout, sim_result.stderr])
    summary["simulation_returncode"] = sim_result.returncode
    passed_marker = "RESULT: PASS" in sim_result.stdout
    failed_marker = "RESULT: FAIL" in sim_result.stdout
    success = compile_result.returncode == 0 and sim_result.returncode == 0 and passed_marker and not failed_marker
    summary.update({"status": "PASS" if success else "FAIL", "passed_marker": passed_marker, "failed_marker": failed_marker})
    LOG.write_text("\n".join(transcript), encoding="utf-8")
    SUMMARY.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print("SIMULATION SUCCESS" if success else "SIMULATION FAIL; inspect workspace/reports/sim_output.log")
    return 0 if success else 1

if __name__ == "__main__":
    raise SystemExit(main())