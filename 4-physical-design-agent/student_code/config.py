"""Paths and pinned backend defaults used by the Assignment 4 starter."""

from __future__ import annotations

import os
from pathlib import Path


LAB_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_DIR = LAB_ROOT / "template"

# The design under optimization is YOUR pipelined RV32I core from Assignment 3.
# Drop your verified core into core/ : the top-level datapath plus its six submodules.
# The RTL is FROZEN in this assignment -- you tune synthesis/PnR parameters, not the RTL.
DESIGN_NAME = "datapath_pipelined"
DESIGN_PATH = LAB_ROOT / "core"
RTL_FILES = (
    DESIGN_PATH / "datapath_pipelined.sv",
    DESIGN_PATH / "submodules" / "alu.sv",
    DESIGN_PATH / "submodules" / "regfile.sv",
    DESIGN_PATH / "submodules" / "extend.sv",
    DESIGN_PATH / "submodules" / "controller.sv",
    DESIGN_PATH / "submodules" / "branch_unit.sv",
    DESIGN_PATH / "submodules" / "memory_access.sv",
)

PLATFORM = "asap7"
ORFS_FLOW_DIR = Path(
    os.environ.get("ORFS_FLOW_DIR", "/OpenROAD-flow-scripts/flow")
)

# output/ is a graded deliverable and lives at the package root (A4_student/output),
# matching the handout, README, and grader. The work/script dirs are internal
# scratch and are excluded from submission.
DEFAULT_OUTPUT_DIR = LAB_ROOT / "output"
DEFAULT_SCRIPT_DIR = LAB_ROOT / "generated_scripts"
DEFAULT_WORK_DIR = LAB_ROOT / "orfs_work"

DEFAULT_CONFIG_TEMPLATE = TEMPLATE_DIR / "config_template.mk"
DEFAULT_CONSTRAINT_TEMPLATE = TEMPLATE_DIR / "constraint_template.sdc"

DEFAULT_MODEL = "gpt-5.4-mini"
DEFAULT_TRIALS = 5

# These constraints are fixed across the baseline and all tuned trials. They
# are infrastructure constants, not part of the LLM-controlled search space.
CLOCK_PERIOD_PS = 1000.0
IO_DELAY_PS = 100.0
