// *********************************************************
// Copyright (c) 2021 Demand Peripherals, Inc.
//
// This file is licensed separately for private and commercial
// use.  See LICENSE.txt which should have accompanied this file
// for details.  If LICENSE.txt is not available please contact
// support@demandperipherals.com to receive a copy.
//
// In general, you may use, modify, redistribute this code, and
// use any associated patent(s) as long as
// 1) the above copyright is included in all redistributions,
// 2) this notice is included in all source redistributions, and
// 3) this code or resulting binary is not sold as part of a
//    commercial product.  See LICENSE.txt for definitions.
//
// DPI PROVIDES THE SOFTWARE "AS IS," WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
// WITHOUT LIMITATION ANY WARRANTIES OR CONDITIONS OF TITLE,
// NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR
// PURPOSE.  YOU ARE SOLELY RESPONSIBLE FOR DETERMINING THE
// APPROPRIATENESS OF USING OR REDISTRIBUTING THE SOFTWARE (WHERE
// ALLOWED), AND ASSUME ANY RISKS ASSOCIATED WITH YOUR EXERCISE OF
// PERMISSIONS UNDER THIS AGREEMENT.
//
// This software may be covered by US patent #10,324,889. Rights
// to use these patents is included in the license agreements.
// See LICENSE.txt for more information.
// *********************************************************


// *********************************************************
// DIRECTIONS:
//    git clone https://github.com/peripheralcontrol/pccore.git
//    cd pccore/fpgaboards/baseboard4
//    # edit perilist to include only bb4io and out4
//    vi perilist # make sure the second peripheral is 'out4'
//    make   # OK if this fails.  We only want build/main.v
//    cd ../../peripherals/testbench
//    make bb4out4_tb.xt2
//    gtkwave -a bb4out4_tb.gtkw
//
// This file tests bb4io and the 'send on change' feature.
// *********************************************************
`timescale 1ns/1ns


module bb4out4_tb();
    reg   ck100mhz;                   // 100 MHz clock from PLL or testbench
    inout  [`BRD_MX_IO:0]  BRDIO;     // Board IO 
    inout  [`MX_PCPIN:0]   PCPIN;     // Peripheral Controller Pins (for Pmods)

    reg    [7:0] datin;               // Data from USB to FPGA
    reg    ifrxf;                     // RX full from FTDI part
    reg    iftxe;                     // TX empty from FTDI part
    wire   ifrd;                      // read strobe from FPGA

    pccore main_dut(BRDIO, PCPIN);
    assign BRDIO[`BRD_CLOCK] = ck100mhz;
    assign BRDIO[`BRD_RXF_] = ifrxf;
    assign BRDIO[`BRD_TXE_] = iftxe;
    assign ifrd = BRDIO[`BRD_RD_];
    assign BRDIO[`BRD_DATA_7:`BRD_DATA_0] = datin;

    // generate the clock(s)
    initial  ck100mhz = 0;
    always   #5 ck100mhz = ~ck100mhz;


    // Test the device
    initial
    begin
        $dumpfile ("bb4out4_tb.xt2");
        $dumpvars (0, bb4out4_tb);
        ifrxf = 1;   // active low
        iftxe = 0;   // active low

        // A packet to write '5' to outval of the out4 in slot1
        // c0 f8 e1 00 01 05 ac b1 c0
        #400; datin = 8'hc0;  // SLIP end
        #100; ifrxf = 0;
        #450; datin = 8'hf8;  // write command
        #550; datin = 8'he1;  // peripheral #
        #550; datin = 8'h00;  // register #
        #550; datin = 8'h01;  // # bytes to write
        #550; datin = 8'h05;  // value to write
        #550; datin = 8'hac;  // CRC
        #550; datin = 8'hb1;  // CRC
        #550; datin = 8'hc0;  // SLIP end
        #550; ifrxf = 1;
        #10000;

        $finish;
    end
endmodule


module BUFG(I, O);
    input  I;
    output O;

    assign O = I;
endmodule

module DCM_SP(
      output CLK0,                       // 0 degree DCM CLK output
      output CLK180,                     // 180 degree DCM CLK output
      output CLK270,                     // 270 degree DCM CLK output
      output CLK2X,                      // 2X DCM CLK output
      output CLK2X180,                   // 2X, 180 degree DCM CLK out
      output CLK90,                      // 90 degree DCM CLK output
      output CLKDV,                      // Divided DCM CLK out (CLKDV_DIVIDE)
      output CLKFX,                      // DCM CLK synthesis out (M/D)
      output CLKFX180,                   // 180 degree CLK synthesis out
      output LOCKED,                     // DCM LOCK status output
      output PSDONE,                     // Dynamic phase adjust done output
      output STATUS,                     // 8-bit DCM status bits output
      input  CLKFB,                      // DCM clock feedback
      input  CLKIN,                      // Clock input (from IBUFG, BUFG or DCM)
      input  PSCLK,                      // Dynamic phase adjust clock input
      input  PSEN,                       // Dynamic phase adjust enable input
      input  PSINCDEC,                   // Dynamic phase adjust increment/decrement
      input  RST                         // DCM asynchronous reset input
   );

    assign CLKFX = CLKIN;

endmodule


