# Fixed timing constraints for every Assignment 4 trial.
current_design datapath_pipelined

set clk_name core_clock
set clk_port_name clk
set clk_period {CLOCK_PERIOD_PS}
set io_delay {IO_DELAY_PS}

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

set virtual_clk_name virtual_$clk_name
create_clock -name $virtual_clk_name -period $clk_period

set non_clock_inputs [all_inputs -no_clocks]
set_input_delay $io_delay -clock $virtual_clk_name $non_clock_inputs
set_output_delay $io_delay -clock $virtual_clk_name [all_outputs]
