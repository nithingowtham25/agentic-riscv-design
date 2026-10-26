# Trial-specific OpenROAD-flow-scripts configuration.
export PLATFORM = asap7
export DESIGN_NAME = datapath_pipelined
export DESIGN_NICKNAME = datapath_pipelined

export VERILOG_FILES = {RTL_FILES}
export VERILOG_INCLUDE_DIRS = {RTL_INCLUDE_DIRS}
export SDC_FILE = {SDC_FILE}
export WORK_HOME = {WORK_HOME}
export FLOW_VARIANT = {TRIAL_ID}

# Equivalence checking is outside this lab's scope. The current upstream
# Kepler-Formal binary also is not portable across all department-server CPUs.
export LEC_CHECK = 0

# LLM-controlled values. Every value must first pass valid_params(...).
export ABC_AREA = {ABC_AREA}
export CORE_UTILIZATION = {CORE_UTILIZATION}
export PLACE_DENSITY = {PLACE_DENSITY}
export GPL_TIMING_DRIVEN = {GPL_TIMING_DRIVEN}
