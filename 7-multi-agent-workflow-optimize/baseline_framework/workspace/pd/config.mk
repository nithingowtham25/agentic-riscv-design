# Assignment 6 isolated ORFS/OpenROAD configuration.
export PLATFORM = asap7
export DESIGN_NAME = memory_access
export DESIGN_NICKNAME = memory_access

export VERILOG_FILES = /workspace/Assignment6/workspace/src/memory_access.sv
export VERILOG_INCLUDE_DIRS = /workspace/Assignment6/workspace/src
export SDC_FILE = /workspace/Assignment6/workspace/pd/memory_access.sdc
export WORK_HOME = /workspace/Assignment6/workspace/pd/orfs_work
export FLOW_VARIANT = a6_memory_access

export LEC_CHECK = 0
export ABC_AREA = 1
export CORE_UTILIZATION = 40
export PLACE_DENSITY = 0.8
export GPL_TIMING_DRIVEN = 1