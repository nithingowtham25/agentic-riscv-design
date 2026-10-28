# Trial-specific OpenROAD-flow-scripts configuration.
export PLATFORM = asap7
export DESIGN_NAME = datapath_pipelined
export DESIGN_NICKNAME = datapath_pipelined

export VERILOG_FILES = /workspace/Assignment4/core/datapath_pipelined.sv /workspace/Assignment4/core/submodules/alu.sv /workspace/Assignment4/core/submodules/regfile.sv /workspace/Assignment4/core/submodules/extend.sv /workspace/Assignment4/core/submodules/controller.sv /workspace/Assignment4/core/submodules/branch_unit.sv /workspace/Assignment4/core/submodules/memory_access.sv
export VERILOG_INCLUDE_DIRS = /workspace/Assignment4/core/submodules
export SDC_FILE = /workspace/Assignment4/output/trial_004/constraint.sdc
export WORK_HOME = /workspace/Assignment4/orfs_work
export FLOW_VARIANT = a4_9a1658acc461_004

# Equivalence checking is outside this lab's scope. The current upstream
# Kepler-Formal binary also is not portable across all department-server CPUs.
export LEC_CHECK = 0

# LLM-controlled values. Every value must first pass valid_params(...).
export ABC_AREA = 1
export CORE_UTILIZATION = 55
export PLACE_DENSITY = 0.7
export GPL_TIMING_DRIVEN = 1
