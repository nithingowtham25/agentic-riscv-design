# `memory_access` is combinational; constrain I/O timing through a virtual clock.
current_design memory_access
set virtual_clk a6_memory_access_io
create_clock -name $virtual_clk -period 10.0
set_input_delay 1.0 -clock $virtual_clk [all_inputs]
set_output_delay 1.0 -clock $virtual_clk [all_outputs]