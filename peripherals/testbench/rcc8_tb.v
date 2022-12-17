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
// rcc8_tb.v : Testbench for the rcc8 peripheral 
//
//  Registers are
//    Addr=0      Transition time of sensor 1 in ticks
//    Addr=1      Transition time of sensor 2 in ticks
//    Addr=2      Transition time of sensor 3 in ticks
//    Addr=3      Transition time of sensor 4 in ticks
//    Addr=4      Transition time of sensor 5 in ticks
//    Addr=5      Transition time of sensor 6 in ticks
//    Addr=6      Transition time of sensor 7 in ticks
//    Addr=7      Transition time of sensor 7 in ticks
//    Addr=8      Config: update interval, clk src, polarity
//
//  The test procedure is as follows:
//  - Set the update interval to 100ms, src to 100us, polarity to pos
//  - Raise all inputs after 50us
//  - Lower inputs after 100,110,120,130,140,150, and 160 us
//  - Verify that data ready flag goes high
//  - Read all 8 time registers and verify times
 
`timescale 1ns/1ns


module rcc8_tb;
    reg    CLK_I;            // system clock
    reg    WE_I;             // direction of this transfer. Read=0; Write=1
    reg    TGA_I;            // ==1 if reg access, ==0 if poll
    reg    STB_I;            // ==1 if this peri is being addressed
    reg    [7:0] ADR_I;      // address of target register
    wire   STALL_O;          // ==1 if we need more clk cycles to complete
    wire   ACK_O;            // ==1 if we claim the above address
    reg    [7:0] DAT_I;      // Data INto the peripheral;
    wire   [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    reg    [8:0] clocks;     // Array of clock pulses from 10ns to 1 second
    wire   [7:0] pins;       // Pins to RC timers
    reg    [7:0] rcc;        // inputs from the RC sensors
 

    // Add the device under test
    rcc8 rcc8_dut(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);

    initial rcc = 0;
    assign pins[7:0] = rcc[7:0];

    // generate the clock(s)
    initial  CLK_I = 1;
    always   #25 CLK_I = ~CLK_I;
    initial  clocks = 8'h00;
    always   begin #5 clocks[`N10CLK] = 1;  #5 clocks[`N10CLK] = 0; end
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
        $dumpfile ("rcc8_tb.xt2");
        $dumpvars (0, rcc8_tb);
        //  - Set bus lines and FPGA pins to default state
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;


        #1000    // some time later
        //  - Set the update interval to 10ms, clksrc=1MHz, pos polarity
        WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 8; DAT_I = 8'h41;
        #50
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #100

        // Wait for first 10ms edge to transition out of IDLE
        #10000000

        // Positive polarity so all lines are high
        rcc[7:0] = 8'hff;
        //  - Lower inputs after 100,110,120,130,140,150,160 and 170 us
        #100000 rcc[0] = 1'b0;
        #10000  rcc[1] = 1'b0;
        #10000  rcc[2] = 1'b0;
        #10000  rcc[3] = 1'b0;
        #10000  rcc[4] = 1'b0;
        #10000  rcc[5] = 1'b0;
        #10000  rcc[6] = 1'b0;
        #10000  rcc[7] = 1'b0;
        $display("inputs done at t=", $time);

        // Delay until start of next period and read the counter values
        #100000
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 0; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 1; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 2; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 3; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 4; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 5; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 6; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 7; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 8; DAT_I = 0;
        #100
        #1000000

        $finish;
    end
endmodule



