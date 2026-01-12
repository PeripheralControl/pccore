create_clock -name BRDIO[0] -period 20.0 [get_ports {BRDIO[0]}]
create_clock -add -name ck20mhz -period 50 [get_nets {CLK_O}]

