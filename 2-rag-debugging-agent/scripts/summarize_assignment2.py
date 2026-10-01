#!/usr/bin/env python3
"""Summarize Task 3 seeded repairs and Task 4 ablation JSON logs."""
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / "logs"
OUT = ROOT / "analysis"


def read_records(directory: Path):
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted(directory.glob("*.json"))]


def stats(records):
    passed = [record for record in records if record.get("final_status") == "pass"]
    repairs = [record["iterations"][-1]["iteration"] for record in passed if record.get("iterations")]
    return {
        "runs": len(records),
        "passes": len(passed),
        "failures": len(records) - len(passed),
        "mean_repairs": mean(repairs) if repairs else None,
        "repair_range": f"{min(repairs)}-{max(repairs)}" if repairs else "n/a",
        "successful_runs": len(repairs),
    }


def main():
    OUT.mkdir(exist_ok=True)
    lines = ["# Assignment 2 Ablation Summary", ""]
    groups = defaultdict(list)
    for part in ("part_a", "part_b"):
        for record in read_records(LOGS / "ablation"):
            name = Path(record.get("log_file", "")).name
            # File name is not written by the driver, so infer group from the stored arm and seed.
            inferred_part = "part_b" if record.get("seed_rtl") else "part_a"
            if inferred_part == part:
                groups[(part, record["arm"])].append(record)
    lines += ["| Part | Arm | Runs | Pass rate | Mean repairs (successful only) | Range | Failures |", "|---|---|---:|---:|---:|---|---:|"]
    for (part, arm), records in sorted(groups.items()):
        item = stats(records)
        lines.append(
            f"| {part} | {arm} | {item['runs']} | {item['passes']}/{item['runs']} | "
            f"{item['mean_repairs'] if item['mean_repairs'] is not None else 'n/a'} "
            f"(n={item['successful_runs']}) | {item['repair_range']} | {item['failures']} |"
        )
    (OUT / "ablation_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    seeded_lines = ["# Seeded Bug Repair Summary", "", "| Module | Final status | Repairs | Retrieved sources |", "|---|---|---:|---|"]
    for record in read_records(LOGS / "seeded_repairs"):
        repairs = record["iterations"][-1]["iteration"] if record.get("iterations") else "n/a"
        sources = sorted({chunk.get("source", "unknown") for retrieval in record.get("retrievals", []) for chunk in retrieval.get("chunks", [])})
        seeded_lines.append(f"| {record['module']} | {record['final_status']} | {repairs} | {', '.join(sources) or 'none'} |")
    (OUT / "seeded_bug_summary.md").write_text("\n".join(seeded_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()