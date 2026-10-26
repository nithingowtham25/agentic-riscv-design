"""Provided ORFS template-substitution and tool invocation helpers."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import Any, Sequence

try:
    from .config import DESIGN_NAME, ORFS_FLOW_DIR, PLATFORM
    from .io_utils import read_text, write_text
except ImportError:  # Support `python3 student_code/run_agent.py`.
    from config import DESIGN_NAME, ORFS_FLOW_DIR, PLATFORM
    from io_utils import read_text, write_text


SYNTHESIS_ARTIFACT_KEYS = (
    "synthesis_database",
    "synthesis_netlist",
    "synthesis_log",
    "synthesis_report",
)
PNR_ARTIFACT_KEYS = (
    "final_database",
    "final_netlist",
    "final_sdc",
    "final_gds",
    "final_report_log",
    "final_report",
)


def fill_template(
    template_path: str | Path,
    replacements: dict[str, Any],
) -> str:
    """Replace each ``{key}`` placeholder and return the completed text."""
    completed = read_text(template_path)
    for key, value in replacements.items():
        completed = completed.replace("{" + key + "}", str(value))
    return completed


def unresolved_placeholders(text: str, keys: Sequence[str]) -> list[str]:
    """Return expected replacement keys whose placeholders remain in text."""
    return [key for key in keys if "{" + key + "}" in text]


def run_command(
    command: Sequence[str],
    *,
    cwd: str | Path | None = None,
    log_path: str | Path | None = None,
) -> tuple[bool, str]:
    """Run a command and return (exit_status_is_zero, combined_output)."""
    try:
        completed = subprocess.run(
            list(command),
            cwd=Path(cwd) if cwd is not None else None,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        output = completed.stdout or ""
        success = completed.returncode == 0
    except OSError as error:
        output = f"Failed to start command: {error}\n"
        success = False

    if log_path is not None:
        write_text(log_path, output)
    return success, output


def validate_trial_id(trial_id: str) -> str:
    """Validate a FLOW_VARIANT name before passing it to Make."""
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", trial_id):
        raise ValueError(
            "trial_id must begin with an alphanumeric character and contain "
            "only letters, digits, period, underscore, or hyphen"
        )
    return trial_id


def orfs_trial_paths(
    work_dir: str | Path,
    trial_id: str,
    *,
    design_name: str = DESIGN_NAME,
    platform: str = PLATFORM,
) -> dict[str, Path]:
    """Return the standard ORFS directories and key artifacts for one trial."""
    variant = validate_trial_id(trial_id)
    work_root = Path(work_dir).resolve()
    logs = work_root / "logs" / platform / design_name / variant
    reports = work_root / "reports" / platform / design_name / variant
    results = work_root / "results" / platform / design_name / variant
    objects = work_root / "objects" / platform / design_name / variant
    return {
        "work_root": work_root,
        "logs_dir": logs,
        "reports_dir": reports,
        "results_dir": results,
        "objects_dir": objects,
        "synthesis_database": results / "1_synth.odb",
        "synthesis_netlist": results / "1_2_yosys.v",
        "synthesis_log": logs / "1_2_yosys.log",
        "synthesis_metrics_log": logs / "1_2_yosys_metrics.log",
        "synthesis_report": reports / "1_Post_synthesis.rpt",
        "final_database": results / "6_1_fill.odb",
        "final_netlist": results / "6_final.v",
        "final_sdc": results / "6_final.sdc",
        "final_gds": results / "6_final.gds",
        "final_report_log": logs / "6_report.log",
        "final_report": reports / "6_finish.rpt",
        "metadata": reports / "metadata.json",
    }


def missing_artifacts(
    paths: dict[str, Path],
    required_keys: Sequence[str],
) -> list[str]:
    """Return artifact keys that are absent or not regular files."""
    return [key for key in required_keys if not paths[key].is_file()]


def run_orfs_target(
    config_path: str | Path,
    trial_id: str,
    target: str,
    *,
    log_path: str | Path | None = None,
    flow_dir: str | Path = ORFS_FLOW_DIR,
) -> tuple[bool, str]:
    """Run one Make target in the pinned ORFS flow."""
    variant = validate_trial_id(trial_id)
    design_config = Path(config_path).resolve()
    command = [
        "make",
        "-C",
        str(Path(flow_dir)),
        f"DESIGN_CONFIG={design_config}",
        f"FLOW_VARIANT={variant}",
        target,
    ]
    return run_command(command, log_path=log_path)


def run_synthesis(
    config_path: str | Path,
    trial_id: str,
    *,
    log_path: str | Path | None = None,
    flow_dir: str | Path = ORFS_FLOW_DIR,
) -> tuple[bool, str]:
    """Run the ORFS ``synth-report`` target for one isolated variant."""
    return run_orfs_target(
        config_path,
        trial_id,
        "synth-report",
        log_path=log_path,
        flow_dir=flow_dir,
    )


def run_pnr(
    config_path: str | Path,
    trial_id: str,
    *,
    log_path: str | Path | None = None,
    flow_dir: str | Path = ORFS_FLOW_DIR,
) -> tuple[bool, str]:
    """Run the ORFS ``finish`` target for one isolated variant."""
    return run_orfs_target(
        config_path,
        trial_id,
        "finish",
        log_path=log_path,
        flow_dir=flow_dir,
    )


def generate_orfs_metadata(
    config_path: str | Path,
    trial_id: str,
    *,
    log_path: str | Path | None = None,
    flow_dir: str | Path = ORFS_FLOW_DIR,
) -> tuple[bool, str]:
    """Generate ORFS ``metadata.json`` from the completed trial artifacts."""
    return run_orfs_target(
        config_path,
        trial_id,
        "metadata-generate",
        log_path=log_path,
        flow_dir=flow_dir,
    )
