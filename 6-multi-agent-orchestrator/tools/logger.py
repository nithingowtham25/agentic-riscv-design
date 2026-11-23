#!/usr/bin/env python3
"""Structured, transcript-aware logging for the Assignment 6 orchestrator."""
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


def parse_cli_json(raw: str) -> dict[str, Any] | None:
    """Return the first complete CLI result object despite trailing warning text."""
    decoder = json.JSONDecoder()
    for index, char in enumerate(raw):
        if char != "{":
            continue
        try:
            value, _ = decoder.raw_decode(raw[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and ("usage" in value or value.get("type") == "result"):
            return value
    return None


def usage_from_transcript(raw: str) -> dict[str, Any]:
    """Normalize standard Claude CLI and TAMU gateway usage metadata."""
    payload = parse_cli_json(raw)
    zero: dict[str, Any] = {
        "usage_available": False, "input_tokens": 0, "output_tokens": 0,
        "cache_read_tokens": 0, "cache_creation_tokens": 0, "thinking_tokens": 0,
        "total_cost_usd": None, "duration_api_ms": None, "duration_ms": None,
        "num_turns": None, "model": None,
    }
    if not payload:
        return zero
    usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else {}
    model_usage = payload.get("modelUsage") if isinstance(payload.get("modelUsage"), dict) else {}
    model, model_row = next(iter(model_usage.items()), (None, {}))
    if not isinstance(model_row, dict):
        model_row = {}
    def count(*keys: str) -> int:
        for key in keys:
            value = usage.get(key, model_row.get(key))
            if isinstance(value, (int, float)):
                return int(value)
        return 0
    details = usage.get("output_tokens_details", {})
    thinking = details.get("thinking_tokens", model_row.get("thinkingTokens", 0)) if isinstance(details, dict) else 0
    return {
        "usage_available": bool(usage or model_usage),
        "input_tokens": count("input_tokens", "inputTokens"),
        "output_tokens": count("output_tokens", "outputTokens"),
        "cache_read_tokens": count("cache_read_input_tokens", "cacheReadInputTokens"),
        "cache_creation_tokens": count("cache_creation_input_tokens", "cacheCreationInputTokens"),
        "thinking_tokens": int(thinking or 0),
        "total_cost_usd": payload.get("total_cost_usd", model_row.get("costUSD")),
        "duration_api_ms": payload.get("duration_api_ms"),
        "duration_ms": payload.get("duration_ms"),
        "num_turns": payload.get("num_turns"), "model": model or payload.get("model"),
    }


class RunLogger:
    def __init__(self, reports: Path, run_id: str, run_dir: Path) -> None:
        self.reports, self.run_id, self.run_dir = reports, run_id, run_dir
        self.path = reports / "orchestration_state.json"
        self.data: dict[str, Any] = {"run_id": run_id, "run_dir": str(run_dir), "started_at": now(),
            "status": "RUNNING", "stages": [], "notes": []}
        self.persist()

    def persist(self) -> None:
        write_json(self.path, self.data)
        totals: dict[str, Any] = {"calls": 0, "usage_available_calls": 0, "input_tokens": 0,
            "output_tokens": 0, "cache_read_tokens": 0, "cache_creation_tokens": 0,
            "thinking_tokens": 0, "total_cost_usd": 0.0, "cost_available": False}
        rows = []
        for stage in self.data["stages"]:
            if stage.get("kind") != "agent":
                continue
            row = {key: stage.get(key) for key in ("stage", "attempt", "status", "detail", "transcript", "elapsed_seconds")}
            row.update(stage.get("usage", {})); rows.append(row); totals["calls"] += 1
            if row.get("usage_available"):
                totals["usage_available_calls"] += 1
            for key in ("input_tokens", "output_tokens", "cache_read_tokens", "cache_creation_tokens", "thinking_tokens"):
                totals[key] += int(row.get(key) or 0)
            if isinstance(row.get("total_cost_usd"), (int, float)):
                totals["total_cost_usd"] += float(row["total_cost_usd"]); totals["cost_available"] = True
        write_json(self.reports / "token_usage.json", {"run_id": self.run_id, "run_dir": str(self.run_dir),
            "totals": totals, "per_agent": rows,
            "note": "Usage is parsed from raw Claude CLI transcripts; gateway warning text is retained but ignored."})

    def record(self, stage: str, *, kind: str, status: str, detail: str = "", attempt: int = 1,
               artifacts: list[str] | None = None, usage: dict[str, Any] | None = None,
               transcript: str | None = None, elapsed_seconds: float | None = None) -> None:
        self.data["stages"].append({"stage": stage, "kind": kind, "status": status,
            "timestamp": now(), "detail": detail, "attempt": attempt, "artifacts": artifacts or [],
            "usage": usage or {}, "transcript": transcript, "elapsed_seconds": elapsed_seconds})
        self.persist()

    def transition(self, status: str, note: str = "") -> None:
        self.data["status"] = status
        if note:
            self.data["notes"].append({"timestamp": now(), "note": note})
        self.persist()
