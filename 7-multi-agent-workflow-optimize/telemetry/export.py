"""Turn native OTLP JSON files into CSVs and a student-readable report."""

import argparse
from collections import Counter
import csv
import json
from pathlib import Path


def value(item):
    if not isinstance(item, dict):
        return item
    if "arrayValue" in item:
        return [value(v) for v in item["arrayValue"].get("values", [])]
    if "kvlistValue" in item:
        return attributes(item["kvlistValue"].get("values", []))
    return next(iter(item.values()), None)


def attributes(items):
    return {item["key"]: value(item.get("value", {})) for item in items}


def records(path, signal, warnings):
    if not path.exists():
        return
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        try:
            packet = json.loads(line)
            for resource in packet.get("resource" + signal, []):
                for scope in resource.get("scope" + signal, []):
                    field = {
                        "Logs": "logRecords",
                        "Spans": "spans",
                        "Metrics": "metrics",
                    }[signal]
                    for record in scope.get(field, []):
                        if not isinstance(record, dict):
                            raise ValueError("Expected an OTLP record object")
                        yield record
        except (ValueError, TypeError, AttributeError, KeyError) as exc:
            warnings.append(f"{path.name}:{line_number}: malformed packet ({exc})")


def write_csv(path, rows, fields=None):
    fields = fields or sorted({key for row in rows for key in row}) or ["unavailable"]
    with path.open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    k: json.dumps(v) if isinstance(v, (dict, list)) else v
                    for k, v in row.items()
                }
            )


def export(folder):
    folder = Path(folder)
    warnings, events, spans, metrics = [], [], [], []
    timer = {}
    if (folder / "timer.json").exists():
        try:
            timer = json.loads((folder / "timer.json").read_text())
        except (ValueError, TypeError):
            warnings.append("timer.json is malformed")
    seen = set()
    for record in records(folder / "logs.jsonl", "Logs", warnings):
        try:
            row = attributes(record.get("attributes", []))
            row.update(
                time_ns=record.get("timeUnixNano"),
                trace_id=record.get("traceId"),
                span_id=record.get("spanId"),
            )
            row["event.name"] = str(
                row.get("event.name") or value(record.get("body", {}))
            ).removeprefix("claude_code.")
            key = (
                row.get("session.id"),
                row.get("event.sequence"),
                row.get("event.name"),
            )
            if row.get("event.sequence") is not None:
                if key in seen:
                    continue
                seen.add(key)
            events.append(row)
        except (ValueError, TypeError, AttributeError, KeyError):
            warnings.append("Malformed log record omitted")
    for record in records(folder / "traces.jsonl", "Spans", warnings):
        try:
            row = attributes(record.get("attributes", []))
            row.update(
                name=record.get("name"),
                trace_id=record.get("traceId"),
                span_id=record.get("spanId"),
                parent_span_id=record.get("parentSpanId"),
                status=record.get("status"),
            )
            row["duration_ms"] = (
                int(record["endTimeUnixNano"]) - int(record["startTimeUnixNano"])
            ) / 1e6
            spans.append(row)
        except (ValueError, TypeError, AttributeError, KeyError):
            warnings.append("Malformed span omitted")
    for metric in records(folder / "metrics.jsonl", "Metrics", warnings):
        for kind in ("sum", "gauge", "histogram", "exponentialHistogram"):
            data = metric.get(kind, {})
            for point in data.get("dataPoints", []):
                metrics.append(
                    {
                        "name": metric.get("name"),
                        "unit": metric.get("unit"),
                        "kind": kind,
                        "temporality": data.get("aggregationTemporality"),
                        "point": point,
                    }
                )
    groups = {
        name: [e for e in events if e["event.name"] == name]
        for name in (
            "tool_result",
            "subagent_completed",
            "api_request",
            "api_error",
            "assistant_response",
            "tool_decision",
        )
    }
    # Successful API-event totals only; don't add spans or periodic metric snapshots again.
    requests, ids = [], set()
    for row in groups["api_request"]:
        key = (row.get("session.id"), row.get("request_id"))
        if row.get("request_id"):
            if key in ids:
                continue
            ids.add(key)
        requests.append(row)
    usage = {}
    for field in (
        "input_tokens",
        "output_tokens",
        "cache_read_tokens",
        "cache_creation_tokens",
        "cost_usd",
    ):
        try:
            usage[field] = sum(float(r[field]) for r in requests) if requests else None
        except (KeyError, TypeError, ValueError):
            usage[field] = None
            warnings.append(f"{field} unavailable on one or more API events")
    if not requests:
        warnings.append("No API request usage events received; totals are unavailable")
    if not events:
        warnings.append(
            "No native OTel events received; telemetry is unavailable, not zero usage"
        )
    if not spans:
        warnings.append(
            "No native spans received; beta tracing or export may be unavailable"
        )
    if (folder / "shutdown-warning.txt").exists():
        warnings.append((folder / "shutdown-warning.txt").read_text().strip())
    summary = {
        "events": len(events),
        "spans": len(spans),
        "completed_agent_calls": len(groups["subagent_completed"]),
        "roles": dict(
            Counter(
                e.get("agent_type", "unavailable") for e in groups["subagent_completed"]
            )
        ),
        "completed_tool_calls": len(groups["tool_result"]),
        "failed_tool_calls": sum(
            str(e.get("success")).lower() == "false" for e in groups["tool_result"]
        ),
        "reported_api_requests": len(requests),
        "api_error_events": len(groups["api_error"]),
        "workflow_wall_time_s": timer.get("wall_time_s"),
        "workflow_exit_code": timer.get("exit_code"),
        "usage": usage,
        "warnings": sorted(set(warnings)),
    }
    for name, rows in [
        ("events", events),
        ("spans", spans),
        ("tools", groups["tool_result"]),
        ("agents", groups["subagent_completed"]),
        ("requests", requests),
        ("messages", groups["assistant_response"]),
        ("decisions", groups["tool_decision"]),
        ("metrics", metrics),
    ]:
        write_csv(folder / (name + ".csv"), rows)
    (folder / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    lines = [
        "# Native OpenTelemetry report",
        "",
        "| Measurement | Value |",
        "|---|---|",
    ]
    for key, number in {
        **{
            k: v
            for k, v in summary.items()
            if isinstance(v, (int, float)) and not isinstance(v, bool)
        },
        **usage,
    }.items():
        lines.append(f"| {key} | {'unavailable' if number is None else number} |")
    lines += ["", "Roles: " + json.dumps(summary["roles"]), "", "## Data quality", ""]
    lines += ["- " + warning for warning in summary["warnings"]] or [
        "No parsing/export warnings detected."
    ]
    lines += [
        "",
        "Counts cover received completed events; interrupted calls may lack completion records. Spans retain parent IDs for the native call tree. Token/cost totals sum reported API request events once, including any subagent events received; they are not independently verified billing. Periodic metrics are exported separately and are not summed again.",
        "",
        "No custom hook collection or file snapshots are used. Agent output correctness and hardware/PPA metrics belong to the project evaluator. Tool details and public assistant text may appear in these local files; prompts and raw API bodies are disabled. Hidden reasoning is not reconstructed.",
        "",
    ]
    (folder / "report.md").write_text("\n".join(lines))
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder")
    export(parser.parse_args().folder)
