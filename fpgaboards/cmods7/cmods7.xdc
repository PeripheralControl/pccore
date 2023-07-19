## This file is a modification of the  general .xdc for the Digilent CmodS7

# 12 MHz Clock
set_property -dict { PACKAGE_PIN M9  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[0] }];
create_clock -period 83.33 -waveform {0 41.66} [get_ports { BRDIO[0] }];
# USB-RS232
set_property -dict { PACKAGE_PIN L12 IOSTANDARD LVCMOS33 } [get_ports { BRDIO[1] }]; # tx to the host
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { BRDIO[2] }]; # rx from the host
#set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[1] }]; #pio26 alternate tx
#set_property -dict { PACKAGE_PIN K14 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[2] }]; #pio27 alternate rx
# Push Buttons
set_property -dict { PACKAGE_PIN D2  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[3] }];
set_property -dict { PACKAGE_PIN D1  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[4] }];
set_property PULLDOWN true [get_ports {BRDIO[3]}]; #
set_property PULLDOWN true [get_ports {BRDIO[4]}]; #
# RGB LEDs
set_property -dict { PACKAGE_PIN F1  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[5] }]; # Blue
set_property -dict { PACKAGE_PIN D3  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[6] }]; # Green
set_property -dict { PACKAGE_PIN F2  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[7] }]; # Red
# LEDs
set_property -dict { PACKAGE_PIN E2  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[8] }];
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[9] }];
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[10] }];
set_property -dict { PACKAGE_PIN E1  IOSTANDARD LVCMOS33 } [get_ports { BRDIO[11] }];

# Peripheral pins
set_property -dict { PACKAGE_PIN N2  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[0] }]; #pio4 Slot 1 pin 0 
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[1] }]; #pio3 
set_property -dict { PACKAGE_PIN M4  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[2] }]; #pio2 
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[3] }]; #pio1

set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[4] }]; #pio8 Slot 2 pin 0 
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[5] }]; #pio7 
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[6] }]; #pio6 
set_property -dict { PACKAGE_PIN M2  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[7] }]; #pio5

set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[8] }]; #pio19 Slot 3 pin 0
set_property -dict { PACKAGE_PIN N13 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[9] }]; #pio18 
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[10] }]; #pio17 
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[11] }]; #pio16

set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[12] }]; #pio23 Slot 4 pin 0
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[13] }]; #pio22 
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[14] }]; #pio21 
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[15] }]; #pio20

set_property -dict { PACKAGE_PIN J11 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[16] }]; #pio31 Slot 5 pin 0
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[17] }]; #pio30 
set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[18] }]; #pio29
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { PCPIN[19] }]; #pio28

set_property -dict { PACKAGE_PIN C1  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[20] }]; #pio44 Slot 6 pin 0 
set_property -dict { PACKAGE_PIN B1  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[21] }]; #pio43
set_property -dict { PACKAGE_PIN B2  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[22] }]; #pio42 
set_property -dict { PACKAGE_PIN A2  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[23] }]; #pio41

set_property -dict { PACKAGE_PIN A4  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[24] }]; #pio48 Slot 7 pin 0 
set_property -dict { PACKAGE_PIN A3  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[25] }]; #pio47 
set_property -dict { PACKAGE_PIN B4  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[26] }]; #pio46 
set_property -dict { PACKAGE_PIN B3  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[27] }]; #pio45

## Pmod connector mounted directly on the CmodS7
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[28] }]; # ja1  Slot 8 pin 0
set_property -dict { PACKAGE_PIN H2  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[29] }]; # ja2
set_property -dict { PACKAGE_PIN H4  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[30] }]; # ja3
set_property -dict { PACKAGE_PIN F3  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[31] }]; # ja4
set_property -dict { PACKAGE_PIN H3  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[32] }]; # ja5  Slot 9 pin 0
set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[33] }]; # ja6
set_property -dict { PACKAGE_PIN G1  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[34] }]; # ja7
set_property -dict { PACKAGE_PIN F4  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[35] }]; # ja8
# Unused 
set_property -dict { PACKAGE_PIN N1  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[36] }]; #pio9  Slot 10 pin 0
set_property -dict { PACKAGE_PIN C5  IOSTANDARD LVCMOS33 } [get_ports { PCPIN[37] }]; #pio40 Slot 10 pin 1


## Configuration options
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]


##Quad SPI Flash
##Note that CCLK_0 cannot be placed in 7 series devices. You can access it using the
##STARTUPE2 primitive.
#set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {QspiDB[0]}]
#set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports {QspiDB[1]}]
#set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports {QspiDB[2]}]
#set_property -dict { PACKAGE_PIN F18 IOSTANDARD LVCMOS33 } [get_ports {QspiDB[3]}]
#set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports QspiCSn]



