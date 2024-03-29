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
//    # edit perilist to include only bb4io and sndgen
//    vi perilist # make sure the first peripheral is 'sndgen'
//    make   # OK if this fails.  We only want build/main.v
//    cd ../../peripherals/testbench
//    make bb4sndgen_tb.xt2
//    gtkwave -a bb4sndgen_tb.gtkw
//
// *********************************************************
`timescale 1ns/1ns


module bb4sndgen_tb();
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
        $dumpfile ("bb4sndgen_tb.xt2");
        $dumpvars (0, bb4sndgen_tb);
        iftxe = 0;   // active low

        // A packet to set the VCOs, LFO, and noise generator
        // c0 fa e1 00 0a 01 ff 08 00 10 04 ff ff ff 01 46 28 c0
        #400; datin = 8'hc0;  // SLIP end
        #100; ifrxf = 0;   // active low
        #450; datin = 8'hfa;  // write command
        #550; datin = 8'he1;  // peripheral #
        #550; datin = 8'h00;  // register #
        #550; datin = 8'h0a;  // # bytes to write
        #550; datin = 8'h01;  // value to write
        #550; datin = 8'hff;  // value to write
        #550; datin = 8'h08;  // value to write
        #550; datin = 8'h00;  // value to write
        #550; datin = 8'h10;  // value to write
        #550; datin = 8'h04;  // value to write
        #550; datin = 8'hff;  // value to write
        #550; datin = 8'hff;  // value to write
        #550; datin = 8'hff;  // value to write
        #550; datin = 8'h01;  // value to write
        #550; datin = 8'h46;  // CRC
        #550; datin = 8'h28;  // CRC
        #550; datin = 8'hc0;  // SLIP end
        #550; ifrxf = 1;
        #10000000;

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


