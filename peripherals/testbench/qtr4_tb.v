// *********************************************************
// Copyright (c) 2022 Demand Peripherals, Inc.
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

/////////////////////////////////////////////////////////////////////////
// qtr4_tb.v : Testbench for the qtr4 optical sensor 
//
//  Registers are
//  0  :   Sensor values in low 4 LSBs.  1==black level detected.
//  1  :   8 bits sensitivity value.  This is the number of 10us
//         periods to wait until reading the sensor.
//  2  :   Sample period in units of 10 ms.  0 turns off sampling
//
//  The test procedure is as follows:
//  - Set V/I output values to 0
//  - Set the freq divider value ==19 ( for a divide by 20)
//  - set the rdiv divider value ==15 ( for a divide by 16)
 
`timescale 1ns/1ns


module qtr4_tb;
    reg    CLK_I;            // system clock
    reg    WE_I;             // direction of this transfer. Read=0; Write=1
    reg    TGA_I;            // ==1 if reg access, ==0 if poll
    reg    STB_I;            // ==1 if this peri is being addressed
    reg    [7:0] ADR_I;      // address of target register
    wire   STALL_O;          // ==1 if we need more clk cycles to complete
    wire   ACK_O;            // ==1 if we claim the above address
    reg    [7:0] DAT_I;      // Data INto the peripheral;
    wire   [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    reg    [8:0] clocks;     // Array of clock pulses from 100ns to 1 second
    wire   [3:0] pins;       // Pins to/from qtr4 board.
 

    // Add the device under test
    qtr4 qtr4_dut(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);

    // generate the clock(s)
    initial  CLK_I = 1;
    always   #25 CLK_I = ~CLK_I;
    initial  clocks = 8'h00;
    always   begin #50 clocks[`N100CLK] = 1;  #50 clocks[`N100CLK] = 0; end
    always   begin #950 clocks[`U1CLK] = 1;  #50 clocks[`U1CLK] = 0; end
    always   begin #9950 clocks[`U10CLK] = 1;  #50 clocks[`U10CLK] = 0; end
    always   begin #99950 clocks[`U100CLK] = 1;  #50 clocks[`U100CLK] = 0; end
    always   begin #999950 clocks[`M1CLK] = 1;  #50 clocks[`M1CLK] = 0; end
    always   begin #9999950 clocks[`M10CLK] = 1;  #50 clocks[`M10CLK] = 0; end
    always   begin #99999950 clocks[`M100CLK] = 1;  #50 clocks[`M100CLK] = 0; end
    always   begin #999999950 clocks[`S1CLK] = 1;  #50 clocks[`S1CLK] = 0; end


    // Test the device
    initial
    begin
        $display($time);
        $dumpfile ("qtr4_tb.xt2");
        $dumpvars (0, qtr4_tb);
        //  - Set bus lines and FPGA pins to default state
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;


        #1000    // some time later
        //  - Set V/I output values to 0
        WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 1; DAT_I = 2; #50
        WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 2; DAT_I = 2; #50


        #30000000

        $finish;
    end
endmodule



