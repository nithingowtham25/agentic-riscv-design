#!/usr/bin/env python3
"""Closed-loop, versioned-run controller for the Assignment 6 workflow."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from logger import RunLogger, usage_from_transcript

ROOT = Path(__file__).resolve().parents[1]
STAGE_FILE = {"rtl": "RTL_AGENT.md", "tb": "TB_AGENT.md", "debug": "DEBUG_AGENT.md",
              "verify": "VERIFY_AGENT.md", "pd": "PD_AGENT.md"}


def timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def relative(path: Path) -> str:
    return str(path.relative_to(ROOT))


def load_target() -> dict[str, Any]:
    target = json.loads((ROOT / "workspace/target.json").read_text(encoding="utf-8"))
    required = ("module_name", "rtl_filename", "tb_filename", "tb_top", "spec_path", "pd_sdc_path", "flow_variant")
    missing = [key for key in required if not target.get(key)]
    if missing:
        raise ValueError(f"workspace/target.json missing: {', '.join(missing)}")
    return target


def show_start(number: int, total: int, label: str, detail: str) -> None:
    print(f"[{number:02d}/{total:02d}] {label:<18} START  {detail}", flush=True)


def show_end(number: int, total: int, label: str, status: str, detail: str) -> None:
    print(f"[{number:02d}/{total:02d}] {label:<18} {status:<5}  {detail}", flush=True)


def stage_context(target: dict[str, Any], run_dir: Path) -> str:
    return "\n".join((
        f"RUN_DIR={relative(run_dir)}",
        f"REPORTS_DIR={relative(run_dir / 'reports')}",
        f"RTL_PATH={relative(run_dir / 'src' / target['rtl_filename'])}",
        f"TB_PATH={relative(run_dir / 'tb' / target['tb_filename'])}",
        f"MODULE_NAME={target['module_name']}", f"TB_TOP={target['tb_top']}",
        f"SPEC_PATH={target['spec_path']}", f"REFERENCE_PATH={target.get('reference_path', '')}",
        f"PD_SDC_PATH={target['pd_sdc_path']}", f"FLOW_VARIANT={target['flow_variant']}",
    ))


def invoke_agent(stage: str, attempt: int, index: int, logger: RunLogger, target: dict[str, Any], run_dir: Path, extra: str) -> bool:
    label, total = f"{stage.upper()} Agent", 8
    show_start(index, total, label, f"attempt={attempt}")
    instruction = ROOT / "sub_agents" / STAGE_FILE[stage]
    prompt = f"""You are the {stage.upper()} specialist in a reusable Assignment 6 hardware workflow.
Work from {ROOT}. Read AGENTS.md, then {relative(instruction)}. Follow the ownership rules exactly.
Runtime target configuration:
{stage_context(target, run_dir)}

Controller context:
{extra}

Perform this stage now. Inspect and edit only files you own. Do not merely propose code: create or update the required artifact. End with a concise artifact summary."""
    started = time.monotonic()
    try:
        completed = subprocess.run(["claude", "-p", prompt, "--output-format", "json", "--dangerously-skip-permissions"],
            cwd=ROOT, capture_output=True, text=True, check=False, timeout=1200)
        raw = (completed.stdout or "") + ("\nSTDERR:\n" + completed.stderr if completed.stderr else "")
        status, detail = ("PASS", f"returncode={completed.returncode}") if completed.returncode == 0 else ("FAIL", f"returncode={completed.returncode}")
    except (OSError, subprocess.TimeoutExpired) as error:
        raw, status, detail = f"Agent invocation error: {error}\n", "FAIL", str(error)
    elapsed = round(time.monotonic() - started, 2)
    transcript = run_dir / "reports/transcripts" / f"{stage}_{index:02d}.json"
    transcript.parent.mkdir(parents=True, exist_ok=True); transcript.write_text(raw, encoding="utf-8")
    usage = usage_from_transcript(raw)
    logger.record(stage, kind="agent", status=status, detail=detail, attempt=attempt,
        artifacts=[relative(transcript)], usage=usage, transcript=relative(transcript), elapsed_seconds=elapsed)
    token_note = f"out={usage['output_tokens']} in={usage['input_tokens']} cost={usage['total_cost_usd']}"
    show_end(index, total, label, status, f"attempt={attempt} duration={elapsed:.1f}s {token_note}")
    return status == "PASS"


def invoke_tool(name: str, index: int, script: str, args: list[str], logger: RunLogger, run_dir: Path) -> bool:
    total = 8; show_start(index, total, name, "running")
    started = time.monotonic()
    completed = subprocess.run([sys.executable, script, *args], cwd=ROOT, capture_output=True, text=True, check=False)
    elapsed = round(time.monotonic() - started, 2)
    raw = (completed.stdout or "") + ("\nSTDERR:\n" + completed.stderr if completed.stderr else "")
    transcript = run_dir / "reports/transcripts" / f"{name.lower().replace(' ', '_')}_{index:02d}.log"
    transcript.parent.mkdir(parents=True, exist_ok=True); transcript.write_text(raw, encoding="utf-8")
    status = "PASS" if completed.returncode == 0 else "FAIL"
    logger.record(name.lower().replace(" ", "_"), kind="tool", status=status, detail=f"returncode={completed.returncode}",
        artifacts=[relative(transcript)], transcript=relative(transcript), elapsed_seconds=elapsed)
    summary = raw.strip().splitlines()[-1] if raw.strip() else "no terminal output"
    show_end(index, total, name, status, f"duration={elapsed:.1f}s {summary}")
    return completed.returncode == 0


def sim_args(target: dict[str, Any], run_dir: Path) -> list[str]:
    return ["--rtl", str(run_dir / "src" / target["rtl_filename"]), "--tb", str(run_dir / "tb" / target["tb_filename"]),
            "--tb-top", target["tb_top"], "--reports", str(run_dir / "reports")]


def sim_context(run_dir: Path) -> str:
    log = run_dir / "reports/sim_output.log"
    return "Latest simulation log:\n" + (log.read_text(encoding="utf-8", errors="replace") if log.exists() else "No simulation log exists.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", default=f"a6_{timestamp()}")
    parser.add_argument("--max-repairs", type=int, default=3)
    parser.add_argument("--skip-synthesis", action="store_true")
    args = parser.parse_args(); target = load_target()
    run_dir = ROOT / "workspace/runs" / args.run_id
    # The shell wrapper creates reports/ first so tee can capture terminal output.
    # Permit only that fresh scaffold; reject any prior run evidence.
    if run_dir.exists():
        existing = list(run_dir.rglob("*"))
        permitted = {run_dir / "reports", run_dir / "reports/terminal_run.log"}
        if any(path not in permitted for path in existing):
            raise SystemExit(f"Refusing to overwrite existing run directory: {relative(run_dir)}")
    for directory in (run_dir / "src", run_dir / "tb", run_dir / "reports/transcripts", run_dir / "pd"):
        directory.mkdir(parents=True, exist_ok=True)
    logger = RunLogger(run_dir / "reports", args.run_id, run_dir)
    print(f"[RUN] id={args.run_id} target={target['module_name']} directory={relative(run_dir)}", flush=True)
    logger.transition("RTL_GENERATION")
    if not invoke_agent("rtl", 1, 1, logger, target, run_dir, "Generate the initial RTL from the authoritative specification."):
        logger.transition("FAILED_RTL_AGENT", "RTL agent invocation failed."); return 1
    if not (run_dir / "src" / target["rtl_filename"]).is_file():
        logger.transition("FAILED_RTL_ARTIFACT", "RTL agent did not create its required file."); return 1
    logger.transition("TB_GENERATION")
    if not invoke_agent("tb", 1, 2, logger, target, run_dir, "Generate a self-checking testbench for the current RTL."):
        logger.transition("FAILED_TB_AGENT", "TB agent invocation failed."); return 1
    if not (run_dir / "tb" / target["tb_filename"]).is_file():
        logger.transition("FAILED_TB_ARTIFACT", "TB agent did not create its required file."); return 1
    logger.transition("INITIAL_SIMULATION")
    simulation_ok = invoke_tool("Simulation", 3, "tools/run_simulation.py", sim_args(target, run_dir), logger, run_dir)
    debug_note = "simulation passed; perform a no-change audit" if simulation_ok else "simulation failed; diagnose and repair RTL"
    if not invoke_agent("debug", 1, 4, logger, target, run_dir, f"{debug_note}.\n{sim_context(run_dir)}"):
        logger.transition("FAILED_DEBUG_AGENT", "Debug agent invocation failed."); return 1
    repair = 0
    while not simulation_ok and repair < args.max_repairs:
        repair += 1
        show_start(4, 8, "Repair loop", f"attempt={repair}/{args.max_repairs}")
        simulation_ok = invoke_tool("Simulation repair", 4, "tools/run_simulation.py", sim_args(target, run_dir), logger, run_dir)
        if not simulation_ok and repair < args.max_repairs:
            if not invoke_agent("debug", repair + 1, 4, logger, target, run_dir, f"Repair attempt {repair + 1}/{args.max_repairs}.\n{sim_context(run_dir)}"):
                logger.transition("FAILED_DEBUG_AGENT", "Debug agent invocation failed."); return 1
    if not simulation_ok:
        logger.transition("FAILED_SIMULATION", "Repair budget exhausted; synthesis skipped."); return 1
    logger.transition("VERIFICATION_AUDIT")
    if not invoke_agent("verify", 1, 5, logger, target, run_dir, "Audit and strengthen targeted verification checks."):
        logger.transition("FAILED_VERIFY_AGENT", "Verification agent invocation failed."); return 1
    if not invoke_tool("Re-simulation", 6, "tools/run_simulation.py", sim_args(target, run_dir), logger, run_dir):
        logger.transition("FAILED_VERIFICATION", "Verification-enhanced testbench did not pass."); return 1
    logger.transition("PHYSICAL_DESIGN")
    if not invoke_agent("pd", 1, 7, logger, target, run_dir, "Prepare and document the isolated ORFS handoff."):
        logger.transition("FAILED_PD_AGENT", "PD agent invocation failed."); return 1
    if not args.skip_synthesis:
        synth_args = ["--rtl", str(run_dir / "src" / target["rtl_filename"]), "--reports", str(run_dir / "reports"),
            "--pd-work", str(run_dir / "pd/orfs_work"), "--top", target["module_name"], "--sdc", target["pd_sdc_path"], "--flow-variant", target["flow_variant"]]
        if not invoke_tool("Synthesis", 8, "tools/run_synthesis.py", synth_args, logger, run_dir):
            logger.transition("FAILED_SYNTHESIS", "Simulation passed but synthesis failed."); return 1
    logger.transition("COMPLETE", "Every specialist completed; final simulation and requested synthesis passed.")
    print(f"[SUMMARY] status=COMPLETE agents={sum(s['kind']=='agent' for s in logger.data['stages'])} repairs={repair}/{args.max_repairs} artifacts={relative(run_dir)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
