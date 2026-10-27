create_clock -name pclk -period 20.000 [get_ports {pclk}]
derive_clock_uncertainty
set_input_delay -clock pclk -max 2.000 [get_ports {presetn paddr[*] pwdata[*] psel penable pwrite}]
set_input_delay -clock pclk -min 0.000 [get_ports {presetn paddr[*] pwdata[*] psel penable pwrite}]
set_output_delay -clock pclk -max 2.000 [get_ports {prdata[*] pready pslverr}]
set_output_delay -clock pclk -min 0.000 [get_ports {prdata[*] pready pslverr}]
