#!/usr/bin/env python3
"""Structured, file-backed logging for the Assignment 6 orchestrator."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _usage(value: Any) -> dict[str, int]:
    totals = {"input_tokens": 0, "output_tokens": 0, "cache_read_tokens": 0, "cache_creation_tokens": 0}
    aliases = {
        "input_tokens": "input_tokens", "output_tokens": "output_tokens",
        "cache_read_input_tokens": "cache_read_tokens",
        "cache_creation_input_tokens": "cache_creation_tokens",
    }
    def visit(item: Any) -> None:
        if isinstance(item, dict):
            for key, target in aliases.items():
                if isinstance(item.get(key), int):
                    totals[target] += item[key]
            for child in item.values():
                visit(child)
        elif isinstance(item, list):
            for child in item:
                visit(child)
    visit(value)
    return totals


class RunLogger:
    def __init__(self, reports: Path, run_id: str) -> None:
        self.reports = reports
        self.run_id = run_id
        self.path = reports / "orchestration_state.json"
        self.data: dict[str, Any] = {
            "run_id": run_id, "started_at": now(), "status": "RUNNING",
            "stages": [], "artifacts": {}, "notes": []
        }
        self.persist()

    def persist(self) -> None:
        write_json(self.path, self.data)
        token_rows = []
        totals = {"calls": 0, "input_tokens": 0, "output_tokens": 0,
                  "cache_read_tokens": 0, "cache_creation_tokens": 0}
        for stage in self.data["stages"]:
            if stage.get("kind") != "agent":
                continue
            row = {"stage": stage["stage"], "status": stage["status"], **stage.get("usage", {})}
            token_rows.append(row)
            totals["calls"] += 1
            for key in totals:
                if key != "calls":
                    totals[key] += int(row.get(key, 0) or 0)
        write_json(self.reports / "token_usage.json", {"run_id": self.run_id, "totals": totals, "per_stage": token_rows})

    def record(self, stage: str, *, kind: str, status: str, detail: str = "",
               artifacts: list[str] | None = None, usage: dict[str, int] | None = None,
               transcript: str | None = None) -> None:
        self.data["stages"].append({
            "stage": stage, "kind": kind, "status": status, "timestamp": now(),
            "detail": detail, "artifacts": artifacts or [], "usage": usage or {},
            "transcript": transcript,
        })
        self.persist()

    def transition(self, status: str, note: str = "") -> None:
        self.data["status"] = status
        if note:
            self.data["notes"].append({"timestamp": now(), "note": note})
        self.persist()

    def agent_usage(self, raw_response: str) -> dict[str, int]:
        try:
            return _usage(json.loads(raw_response))
        except json.JSONDecodeError:
            return {"input_tokens": 0, "output_tokens": 0, "cache_read_tokens": 0, "cache_creation_tokens": 0}