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
//    # edit perilist to include ps2 as the first peripheral
//    vi perilist
//    make   # OK if this fails.  We only want build/main.v
//    cd ../../peripherals/testbench
//    make bb4ps2_tb.xt2
//    gtkwave bb4ps2_tb.xt2
//
// This file tests the SPI peripheral
// *********************************************************
`timescale 1ns/1ns


module bb4ps2_tb();
    reg   ck100mhz;                   // 100 MHz clock from PLL or testbench
    inout  [`BRD_MX_IO:0]  BRDIO;     // Board IO 
    inout  [`MX_PCPIN:0]   PCPIN;     // Peripheral Controller Pins (for Pmods)

    reg    [7:0] datin;               // Data from USB to FPGA
    reg    ifrxf;                     // RX full from FTDI part
    reg    iftxe;                     // TX empty from FTDI part
    wire   ifrd;                      // read strobe from FPGA
    reg    ps2dat;
    reg    ps2clk;

    pccore main_dut(BRDIO, PCPIN);
    assign BRDIO[`BRD_CLOCK] = ck100mhz;
    assign BRDIO[`BRD_RXF_] = ifrxf;
    assign BRDIO[`BRD_TXE_] = iftxe;
    assign ifrd = BRDIO[`BRD_RD_];
    assign BRDIO[`BRD_DATA_7:`BRD_DATA_0] = datin;
    assign PCPIN[0] = ps2dat;
    assign PCPIN[1] = ps2dat;
    assign PCPIN[2] = ps2clk;
    assign PCPIN[3] = ps2clk;

    // generate the clock(s)
    initial  ck100mhz = 0;
    always   #5 ck100mhz = ~ck100mhz;


    // Test the device
    initial
    begin
        $dumpfile ("bb4ps2_tb.xt2");
        $dumpvars (0, bb4ps2_tb);

        ps2dat = 1;
        ps2clk = 1;
        ifrxf = 1;   // active low
        iftxe = 0;   // active low

        #1000    // some time later
        // A scancode of 8'h53 takes 11 edges on 5 clock pulses
        // At 25 KHz each half cycle takes 20 microseconds
        ps2dat = 0;     // start bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 0;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 1;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 0;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 1;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 0;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 0;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 1;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 1;     // data bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 0;     // parity bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        ps2dat = 1;     // stop bit
        #20000; ps2clk = 0; #20000; ps2clk = 1;
        #2000000;                // timeout and send to host
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


