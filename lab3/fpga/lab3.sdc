create_clock -name clk_50 -period 20.000 [get_ports {clk_50}]
derive_clock_uncertainty

# External switches and reset are asynchronous to the system clock.
set_false_path -from [get_ports {reset_n switches[*]}]
set_output_delay -clock clk_50 -max 2.000 [get_ports {leds[*]}]
set_output_delay -clock clk_50 -min 0.000 [get_ports {leds[*]}]
