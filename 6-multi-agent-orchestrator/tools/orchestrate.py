#!/usr/bin/env python3
"""Closed-loop controller for the Assignment 6 Markdown-defined agent workflow."""
from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from logger import RunLogger

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "workspace/reports"
TRANSCRIPTS = REPORTS / "transcripts"
STAGE_FILE = {
    "rtl": "RTL_AGENT.md", "tb": "TB_AGENT.md", "debug": "DEBUG_AGENT.md",
    "verify": "VERIFY_AGENT.md", "pd": "PD_AGENT.md",
}


def timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def invoke_agent(stage: str, logger: RunLogger, context: str) -> bool:
    instruction = ROOT / "sub_agents" / STAGE_FILE[stage]
    prompt = f"""You are the Assignment 6 {stage.upper()} specialist. Work in {ROOT}.
Read AGENTS.md, then read {instruction.relative_to(ROOT)} and comply with its ownership restrictions.
Current controller context follows:\n{context}\n
Perform your stage now. Use tools to inspect and edit only files you own. Do not merely propose code in chat; write the required artifact. End with a brief artifact summary."""
    command = ["claude", "-p", prompt, "--output-format", "json", "--dangerously-skip-permissions"]
    try:
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False, timeout=1200)
        raw = (completed.stdout or "") + ("\nSTDERR:\n" + completed.stderr if completed.stderr else "")
        status = "PASS" if completed.returncode == 0 else "FAIL"
        detail = f"returncode={completed.returncode}"
    except (OSError, subprocess.TimeoutExpired) as error:
        raw = f"Agent invocation error: {error}\n"
        status, detail = "FAIL", str(error)
    path = TRANSCRIPTS / f"{stage}_{len(logger.data['stages']):02d}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(raw, encoding="utf-8")
    logger.record(stage, kind="agent", status=status, detail=detail,
                  artifacts=[str(path.relative_to(ROOT))], usage=logger.agent_usage(raw),
                  transcript=str(path.relative_to(ROOT)))
    print(f"[{stage}] {status}: {detail}")
    return status == "PASS"


def invoke_tool(label: str, script: str, logger: RunLogger) -> bool:
    completed = subprocess.run([sys.executable, script], cwd=ROOT, capture_output=True, text=True, check=False)
    raw = (completed.stdout or "") + ("\nSTDERR:\n" + completed.stderr if completed.stderr else "")
    path = TRANSCRIPTS / f"{label}_{len(logger.data['stages']):02d}.log"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(raw, encoding="utf-8")
    status = "PASS" if completed.returncode == 0 else "FAIL"
    logger.record(label, kind="tool", status=status, detail=f"returncode={completed.returncode}",
                  artifacts=[str(path.relative_to(ROOT))], transcript=str(path.relative_to(ROOT)))
    print(raw.rstrip())
    return completed.returncode == 0


def simulation_context() -> str:
    log = REPORTS / "sim_output.log"
    return "Latest simulation log:\n" + (log.read_text(encoding="utf-8", errors="replace") if log.exists() else "No simulation log exists.")


def repair_until_passes(logger: RunLogger, max_repairs: int, starting_repair: int = 0) -> bool:
    repair = starting_repair
    while repair < max_repairs:
        repair += 1
        invoke_agent("debug", logger, f"Repair attempt {repair}/{max_repairs}.\n{simulation_context()}")
        if invoke_tool(f"simulation_repair_{repair}", "tools/run_simulation.py", logger):
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-repairs", type=int, default=3)
    parser.add_argument("--skip-synthesis", action="store_true")
    args = parser.parse_args()
    REPORTS.mkdir(parents=True, exist_ok=True)
    run_id = f"a6_{timestamp()}"
    logger = RunLogger(REPORTS, run_id)
    logger.transition("RTL_GENERATION")

    if not invoke_agent("rtl", logger, "Create the initial implementation from the authoritative specification."):
        logger.transition("FAILED_RTL_AGENT", "RTL agent invocation failed.")
        return 1
    if not (ROOT / "workspace/src/memory_access.sv").is_file():
        logger.transition("FAILED_RTL_ARTIFACT", "RTL agent did not create workspace/src/memory_access.sv.")
        return 1

    logger.transition("TB_GENERATION")
    if not invoke_agent("tb", logger, "Generate the self-checking testbench for the current RTL."):
        logger.transition("FAILED_TB_AGENT", "TB agent invocation failed.")
        return 1

    logger.transition("INITIAL_SIMULATION")
    simulation_ok = invoke_tool("simulation_initial", "tools/run_simulation.py", logger)
    # The assignment requires every specialist to participate. On a passing run this is a no-change audit;
    # on a failing run it is the first repair action.
    debug_context = simulation_context() + ("\nSimulation passed: perform a no-change RTL audit unless evidence proves a defect." if simulation_ok else "\nSimulation failed: repair the RTL now.")
    invoke_agent("debug", logger, debug_context)
    if not simulation_ok:
        simulation_ok = invoke_tool("simulation_after_debug_1", "tools/run_simulation.py", logger)
        if not simulation_ok:
            simulation_ok = repair_until_passes(logger, args.max_repairs, starting_repair=1)
    if not simulation_ok:
        logger.transition("FAILED_SIMULATION", "Repair budget exhausted; physical design skipped.")
        return 1

    logger.transition("VERIFICATION_AUDIT")
    if not invoke_agent("verify", logger, "Audit and strengthen targeted checks, then write the verification audit note."):
        logger.transition("FAILED_VERIFY_AGENT", "Verification agent invocation failed.")
        return 1
    simulation_ok = invoke_tool("simulation_after_verification", "tools/run_simulation.py", logger)
    if not simulation_ok:
        simulation_ok = repair_until_passes(logger, args.max_repairs)
    if not simulation_ok:
        logger.transition("FAILED_VERIFICATION", "Verification-enhanced simulation did not pass.")
        return 1

    logger.transition("PHYSICAL_DESIGN")
    if not invoke_agent("pd", logger, "Prepare and document the isolated ORFS handoff for the accepted RTL."):
        logger.transition("FAILED_PD_AGENT", "PD agent invocation failed.")
        return 1
    if args.skip_synthesis:
        logger.transition("SIMULATION_COMPLETE", "Synthesis skipped by explicit command-line option.")
        return 0
    if not invoke_tool("synthesis", "tools/run_synthesis.py", logger):
        logger.transition("FAILED_SYNTHESIS", "Simulation passed, but ORFS synthesis failed; inspect synthesis logs.")
        return 1

    logger.transition("COMPLETE", "Every specialist completed and simulation plus synthesis passed.")
    print("A6 ORCHESTRATION COMPLETE")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())