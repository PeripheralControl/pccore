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
// cvcc_tb.v : Testbench for the cvcc power supply controller
//
//  Registers are
//    Addr=0/1    V in as PWM
//    Addr=2/3    I in as PWM
//    Addr=4/5    V out as PWM
//    Addr=6/7    I out as PWM
//    Addr=8      Divide by count to generate FET clock
//    Addr=9      Divide FET clock to get reset
//
//  The test procedure is as follows:
//  - Set V/I output values to 0
 
`timescale 1ns/1ns


module cvcc_tb;
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
    wire   [3:0] pins;       // Pins to/from cvcc board.
 
    integer i;
    reg    vin;              // Load voltage as PWM
    reg    iin;              // Load current as PWM
    reg    refin;            // Reference voltage as a PWM

    // Add the device under test
    cvcc cvcc_dut(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
    assign pins[1] = vin;
    assign pins[2] = iin;
    assign pins[3] = refin;

    // generate the clock(s)
    initial  CLK_I = 1;
    initial  clocks = 8'h00;
    always   #25 CLK_I = ~CLK_I;
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
        $dumpfile ("cvcc_tb.xt2");
        $dumpvars (0, cvcc_tb);

        //  - Set bus lines and FPGA pins to default state
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        vin = 0; iin = 0; refin = 0;

        //  - Set V/I output values to 0
        #500;
        #50; WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 6; DAT_I = 8'h00;
        #50; WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #50; WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 7; DAT_I = 8'h80;
        #50; WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #50; WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 8; DAT_I = 8'h03;  // very high I max
        #50; WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #50; WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 9; DAT_I = 0;
        #50; WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #50; WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 10; DAT_I = 1;
        #50; WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;

        // Each cycle is about 10us long.  Report to the host every 100 cycles.
        for (i = 0; i < 3500 ; i = i+1)
        begin
            #2000
            vin = 0; iin = 0; refin = 0;
            #2000
            vin = 1; iin = 0; refin = 0;
            #2000
            vin = 1; iin = 1; refin = 1;
            #2000
            vin = 1; iin = 0; refin = 0;
            #2000
            vin = 0; iin = 0; refin = 0;
        end

        $finish;
    end
endmodule



