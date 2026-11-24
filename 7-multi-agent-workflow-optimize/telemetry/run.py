"""Run an ordinary command while the official OTel Collector saves local data."""

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from telemetry.export import export


def notice(message):
    """Print launcher progress even when agent output is redirected to log files."""
    line = f"[telemetry] {message}\n".encode()
    try:
        os.write(int(os.environ.get("TELEMETRY_STATUS_FD", "2")), line)
    except (OSError, ValueError):
        sys.stderr.write(line.decode())
        sys.stderr.flush()


def elapsed(seconds):
    minutes, seconds = divmod(int(seconds), 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"


def environment(enabled, endpoint=None):
    # Never inherit a different OTel destination or credentials into this run.
    env = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("OTEL_", "CLAUDE_CODE_OTEL_", "LOCAL_OTEL_"))
        and k
        not in (
            "BETA_TRACING_ENDPOINT",
            "ENABLE_ENHANCED_TELEMETRY_BETA",
            "TRACEPARENT",
            "TRACESTATE",
        )
    }
    env.update(
        CLAUDE_CODE_ENABLE_TELEMETRY="1" if enabled else "0",
        CLAUDE_CODE_ENHANCED_TELEMETRY_BETA="1" if enabled else "0",
    )
    for signal in ("LOGS", "TRACES", "METRICS"):
        env[f"OTEL_{signal}_EXPORTER"] = "otlp" if enabled else "none"
    if enabled:
        env.update(
            OTEL_EXPORTER_OTLP_ENDPOINT=endpoint,
            OTEL_EXPORTER_OTLP_PROTOCOL="http/json",
            OTEL_LOGS_EXPORT_INTERVAL="1000",
            OTEL_TRACES_EXPORT_INTERVAL="1000",
            OTEL_METRIC_EXPORT_INTERVAL="1000",
            OTEL_LOG_TOOL_DETAILS="1",
            OTEL_LOG_USER_PROMPTS="0",
            OTEL_LOG_ASSISTANT_RESPONSES="1",
            OTEL_LOG_TOOL_CONTENT="0",
            OTEL_LOG_RAW_API_BODIES="0",
        )
    return env


@contextmanager
def collect(folder, enabled=True):
    if not enabled:
        notice("collection disabled")
        yield environment(False)
        return
    folder = Path(folder).resolve()
    folder.mkdir(parents=True, exist_ok=False)
    binary = (
        os.environ.get("OTELCOL")
        or shutil.which("otelcol-contrib")
        or str(HERE / ".bin/otelcol-contrib")
    )
    if not Path(binary).is_file():
        raise RuntimeError("Install the collector once: python3 telemetry/install.py")
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        address = f"127.0.0.1:{sock.getsockname()[1]}"
    env = environment(True, "http://" + address)
    collector_env = dict(
        env, LOCAL_OTEL_ENDPOINT=address, LOCAL_OTEL_OUTPUT=str(folder)
    )
    process = None
    with (folder / "collector.log").open("w") as log:
        try:
            process = subprocess.Popen(
                [binary, "--config", str(HERE / "collector.yaml")],
                env=collector_env,
                stdout=log,
                stderr=log,
            )
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError(f"Collector failed; read {folder}/collector.log")
                if "Everything is ready" in (folder / "collector.log").read_text():
                    break
                time.sleep(0.1)
            else:
                raise RuntimeError("Collector startup timed out")
            notice(f"collector ready; output: {folder}")
            yield env
        finally:
            notice("stopping collector and exporting reports")
            if process and process.poll() is None:
                process.terminate()  # Graceful shutdown flushes the file exporters.
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    (folder / "shutdown-warning.txt").write_text(
                        "Collector required forced shutdown; data may be incomplete.\n"
                    )
            if process and process.returncode not in (0, None):
                (folder / "shutdown-warning.txt").write_text(
                    f"Collector exited {process.returncode}; inspect collector.log.\n"
                )
            export(folder)


def run_command(command, env, interval=30):
    """Run the workflow and print a small elapsed-time heartbeat."""
    start = time.monotonic()
    notice("workflow started (agent output is saved in claude/)")
    process = subprocess.Popen(command, env=env)
    while True:
        try:
            code = process.wait(timeout=interval)
            break
        except subprocess.TimeoutExpired:
            notice(f"workflow running; elapsed {elapsed(time.monotonic() - start)}")
    duration = time.monotonic() - start
    notice(f"workflow exited with code {code}; elapsed {elapsed(duration)}")
    return code, duration


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True)
    parser.add_argument("--mode", choices=("on", "off"), default="on")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("Provide a command after --")
    try:
        with collect(args.out, args.mode == "on") as env:
            code, duration = run_command(command, env)
            if args.mode == "on":
                (Path(args.out) / "timer.json").write_text(
                    json.dumps(
                        {"wall_time_s": round(duration, 3), "exit_code": code},
                        indent=2,
                    )
                    + "\n"
                )
        if args.mode == "on":
            summary = json.loads((Path(args.out) / "summary.json").read_text())
            notice(
                "report ready: "
                f"{Path(args.out) / 'report.md'} "
                f"({summary['events']} events, {summary['completed_agent_calls']} agent calls, "
                f"{summary['completed_tool_calls']} tool calls)"
            )
            if not summary["events"] and code == 0:
                print(
                    "No native OTel events received; see telemetry/report.md",
                    file=sys.stderr,
                )
                return 1
        return code if code >= 0 else 128 - code
    except (RuntimeError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
