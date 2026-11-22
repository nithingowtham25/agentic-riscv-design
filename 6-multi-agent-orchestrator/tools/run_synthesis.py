#!/usr/bin/env python3
"""Run isolated ORFS/OpenROAD physical design using the pinned Assignment 4 SIF."""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "workspace/reports"
PD = ROOT / "workspace/pd"
A4_ROOT = ROOT.parent / "4-physical-design-agent"
SIF = A4_ROOT / "lab4-orfs-fall2026-v1.sif"
CONFIG = "/workspace/Assignment6/workspace/pd/config.mk"
FLOW_VARIANT = "a6_memory_access"


def parse_metrics(text: str) -> dict[str, str]:
    patterns = {
        "design_area": r"(?:Design area|Total cell area)\s*[:=]?\s*([0-9.]+)",
        "worst_slack": r"(?:worst slack|wns)\s*[:=]?\s*(-?[0-9.]+)",
        "total_power": r"(?:Total Power|total power)\s*[:=]?\s*([0-9.eE+-]+)",
    }
    found: dict[str, str] = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            found[key] = match.group(1)
    return found


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    log_path = REPORTS / "synthesis_output.log"
    summary_path = REPORTS / "synth_summary.json"
    summary: dict[str, object] = {"timestamp": datetime.now(timezone.utc).isoformat(), "status": "FAIL", "top": "memory_access", "flow_variant": FLOW_VARIANT}
    if not (ROOT / "workspace/src/memory_access.sv").is_file():
        log_path.write_text("ERROR: RTL is missing; synthesis is not attempted.\n", encoding="utf-8")
        summary["reason"] = "missing_rtl"
        summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        return 1
    if not SIF.is_file() or shutil.which("singularity") is None:
        log_path.write_text(f"ERROR: Assignment 4 SIF or singularity is unavailable. Expected SIF: {SIF}\n", encoding="utf-8")
        summary["reason"] = "missing_orfs_runtime"
        summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        return 1

    (PD / "orfs_work").mkdir(parents=True, exist_ok=True)
    command = [
        "singularity", "exec", "--cleanenv", "--bind", f"{ROOT}:/workspace/Assignment6",
        "--cwd", "/workspace/Assignment6", str(SIF), "bash", "-lc",
        f"source /OpenROAD-flow-scripts/env.sh >/dev/null && make -C /OpenROAD-flow-scripts/flow DESIGN_CONFIG={CONFIG} FLOW_VARIANT={FLOW_VARIANT} finish",
    ]
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    transcript = "$ " + " ".join(command) + "\n\n" + (completed.stdout or "") + "\n" + (completed.stderr or "")
    log_path.write_text(transcript, encoding="utf-8")
    report_root = PD / "orfs_work/reports/asap7/memory_access" / FLOW_VARIANT
    report_files = sorted(report_root.rglob("*.rpt")) if report_root.is_dir() else []
    report_text = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in report_files)
    metrics = parse_metrics(report_text + "\n" + transcript)
    summary.update({"returncode": completed.returncode, "reports": [str(p.relative_to(ROOT)) for p in report_files], "metrics": metrics})
    summary["status"] = "PASS" if completed.returncode == 0 and report_files else "FAIL"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    (REPORTS / "synth_summary.rpt").write_text("\n".join([f"STATUS: {summary['status']}", f"TOP: memory_access", f"REPORTS: {len(report_files)}"] + [f"{key.upper()}: {value}" for key, value in metrics.items()]) + "\n", encoding="utf-8")
    print(f"SYNTHESIS {summary['status']}; inspect {log_path.relative_to(ROOT)}")
    return 0 if summary["status"] == "PASS" else 1

if __name__ == "__main__":
    raise SystemExit(main())