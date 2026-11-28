#!/usr/bin/env python3
"""Run isolated ORFS/OpenROAD synthesis for a versioned Assignment 6 run."""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# A7_ORFS_SIF is an Assignment 7 runtime configuration override.  The
# default preserves the original Assignment 6 relative-path behavior.
A4_SIF = Path(os.environ.get("A7_ORFS_SIF", ROOT.parent / "4-physical-design-agent" / "lab4-orfs-fall2026-v1.sif")).expanduser()


def parse_metrics(text: str) -> dict[str, str]:
    patterns = {"design_area": r"(?:Design area|Total cell area)\s*[:=]?\s*([0-9.]+)",
        "worst_slack": r"(?:worst slack|wns)\s*[:=]?\s*(-?[0-9.]+)",
        "total_power": r"(?:Total Power|total power)\s*[:=]?\s*([0-9.eE+-]+)"}
    return {key: match.group(1) for key, pattern in patterns.items() if (match := re.search(pattern, text, re.IGNORECASE))}


def container_path(path: Path) -> str:
    return "/workspace/Assignment6/" + str(path.resolve().relative_to(ROOT)).replace("\\", "/")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rtl", required=True); parser.add_argument("--reports", required=True)
    parser.add_argument("--pd-work", required=True); parser.add_argument("--top", required=True)
    parser.add_argument("--sdc", required=True); parser.add_argument("--flow-variant", required=True)
    args = parser.parse_args()
    rtl, reports, pd_work, sdc = Path(args.rtl).resolve(), Path(args.reports).resolve(), Path(args.pd_work).resolve(), Path(args.sdc).resolve()
    reports.mkdir(parents=True, exist_ok=True); pd_work.mkdir(parents=True, exist_ok=True)
    log, summary_path = reports / "synthesis_output.log", reports / "synth_summary.json"
    summary: dict[str, object] = {"timestamp": datetime.now(timezone.utc).isoformat(), "status": "FAIL", "top": args.top, "flow_variant": args.flow_variant}
    if not rtl.is_file() or not sdc.is_file() or not A4_SIF.is_file() or shutil.which("singularity") is None:
        summary["reason"] = "missing_rtl_constraint_or_orfs_runtime"; log.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8"); print("SYNTHESIS FAIL: prerequisite missing"); return 1
    config = pd_work.parent / "config.mk"
    config.write_text("\n".join(("# Generated per-run ORFS configuration.", "export PLATFORM = asap7", f"export DESIGN_NAME = {args.top}", f"export DESIGN_NICKNAME = {args.top}",
        f"export VERILOG_FILES = {container_path(rtl)}", f"export VERILOG_INCLUDE_DIRS = {container_path(rtl.parent)}", f"export SDC_FILE = {container_path(sdc)}",
        f"export WORK_HOME = {container_path(pd_work)}", f"export FLOW_VARIANT = {args.flow_variant}", "export LEC_CHECK = 0", "export ABC_AREA = 1", "export CORE_UTILIZATION = 40", "export PLACE_DENSITY = 0.8", "export GPL_TIMING_DRIVEN = 1", "")), encoding="utf-8")
    command = ["singularity", "exec", "--cleanenv", "--bind", f"{ROOT}:/workspace/Assignment6", "--cwd", "/workspace/Assignment6", str(A4_SIF), "bash", "-lc",
        f"source /OpenROAD-flow-scripts/env.sh >/dev/null && make -C /OpenROAD-flow-scripts/flow DESIGN_CONFIG={container_path(config)} FLOW_VARIANT={args.flow_variant} finish"]
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    transcript = "$ " + " ".join(command) + "\n\n" + (completed.stdout or "") + "\n" + (completed.stderr or "")
    log.write_text(transcript, encoding="utf-8")
    report_root = pd_work / "reports/asap7" / args.top / args.flow_variant
    files = sorted(report_root.rglob("*.rpt")) if report_root.is_dir() else []
    report_text = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in files)
    summary.update({"returncode": completed.returncode, "reports": [str(path) for path in files], "metrics": parse_metrics(report_text + "\n" + transcript)})
    summary["status"] = "PASS" if completed.returncode == 0 and files else "FAIL"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    lines = [f"STATUS: {summary['status']}", f"TOP: {args.top}", f"REPORTS: {len(files)}"] + [f"{key.upper()}: {value}" for key, value in summary["metrics"].items()]
    (reports / "synth_summary.rpt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"SYNTHESIS {summary['status']}; reports={len(files)} log={log}")
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
