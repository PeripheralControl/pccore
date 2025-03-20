// *********************************************************
// Copyright (c) 2025 Demand Peripherals, Inc.
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

//////////////////////////////////////////////////////////////////////////
//
//  File: patgen64.v;   64 nibble pattern generator
//
//  Registers: (8 bit)
//      Reg 0:  State of output pins in state 0
//      Reg 1:  State of output pins in state 1
//      Reg 2:  State of output pins in state 2
//      Reg 3:  State of output pins in state 3
//      :::::::::::::::::::::::::::::::::::::::::
//      Reg 62: State of output pins in state 62
//      Reg 63: State of output pins in state 63
//      Reg 64: Clock source
//      Reg 65: Repeat length -1 (zero to 63)
//
//      This peripheral is a RAM based 4 bit wide by 64 sequence long
//  pattern generator.  The clock driving the sequence counter can be
//  set by the user to one of the following:
//      0:  Off
//      1:  20 MHz
//      2:  10 MHz
//      3:  5 MHz
//      4:  1 MHz
//      5:  500 KHz
//      6:  100 KHz
//      7:  50 KHz
//      8:  10 KHz
//      9   5 KHz
//     10   1 KHz
//     11:  500 Hz
//     12:  100 Hz
//     13:  50 Hz
//     14:  10 Hz
//     15:  5 Hz
//
//
/////////////////////////////////////////////////////////////////////////
module patgen64(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
    input  CLK_I;            // system clock
    input  WE_I;             // direction of this transfer. Read=0; Write=1
    input  TGA_I;            // ==1 if reg access, ==0 if poll
    input  STB_I;            // ==1 if this peri is being addressed
    input  [7:0] ADR_I;      // address of target register
    output STALL_O;          // ==1 if we need more clk cycles to complete
    output ACK_O;            // ==1 if we claim the above address
    input  [7:0] DAT_I;      // Data INto the peripheral;
    output [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    input  [`MXCLK:0] clocks; // Array of clock pulses from 10ns to 1 second
    inout  [3:0] pins;       // Simple binary output
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [5:0] count;      // Counter that drives the RAM address lines
    reg    [5:0] length;     // Length of repeat cycle
    reg    [3:0] clksrc;     // 20 MHz down to 5 Hz.
    wire   lclk;             // Prescale clock
    reg    lreg;             // Prescale clock divided by two

    initial
    begin
        count = 0;
        length = 4;
        lreg = 0;
        clksrc = 4;
    end

    // Pattern clock sources
    wire m100clk =  clocks[`M100CLK];    // utility 100.0 millisecond pulse
    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse
    wire m1clk   =  clocks[`M1CLK];      // utility 1.000 millisecond pulse
    wire u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse
    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse
    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse
    wire n100clk =  clocks[`N100CLK];    // utility 100.0 nanosecond pulse
    // Generate the clock source for the main counter
    assign lclk = (clksrc[3:1] == 0) ? 1'b1 :    // use CLK_I
                  (clksrc[3:1] == 1) ? n100clk :
                  (clksrc[3:1] == 2) ? u1clk :
                  (clksrc[3:1] == 3) ? u10clk :
                  (clksrc[3:1] == 4) ? u100clk :
                  (clksrc[3:1] == 5) ? m1clk :
                  (clksrc[3:1] == 6) ? m10clk :
                  (clksrc[3:1] == 7) ? m100clk : 1'b0;

    // RAM is driven by the count unless the host is writing a new pattern
    wire [3:0] pgout;        // data out to the pins
    wire [5:0] pgaddr;       // RAM address for reading or writing
    wire wen;                // Write from host
    assign wen = TGA_I && WE_I && myaddr && (ADR_I[6] == 1'b0);
    assign pgaddr = (wen) ? ADR_I[5:0] : count;
    pgram64x4 pgram(pgout,pgaddr,DAT_I[3:0],wen,CLK_I);

    always @(posedge CLK_I)
    begin
        // length and freq are at addr 01xxxxx0 and 01xxxxx1
        if (TGA_I & myaddr & WE_I & (ADR_I[6] == 1'b1))
        begin
            if (ADR_I[0] == 1'b0) 
                clksrc <= DAT_I[3:0];
            else if (ADR_I[0] == 1'b1) 
                length <= DAT_I[5:0];
        end

        // Get the half rate clock
        if (lclk)
            lreg <= ~lreg;
        // Increment the count on appropriate clock edge
        if ((clksrc == 4'h1) ||                        // 20 MHz
            ((clksrc[0] == 0) && (lclk == 1)) ||       // not divided by 2
            ((clksrc[0] == 1) && (lreg == 1) && (lclk == 1)))
        begin
            count <= (count == length) ? 0 : count + 6'h1;
        end
    end

    // Assign the outputs.
    assign pins[3:0] = pgout[3:0];

    assign myaddr = (STB_I) && (ADR_I[7] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                     (TGA_I && (ADR_I[0] == 0)) ? {4'h0,clksrc} :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


// Pattern RAM is 64x4 and has synchronous reads
module pgram64x4(dout,addr,din,wen,clk);
    output   [3:0] dout;
    input    [5:0] addr;
    input    [3:0] din;
    input    wen;
    input    clk;

    reg      [3:0] ram [63:0];
    reg      [3:0] rdreg;

    always@(posedge clk)
    begin
        if (wen)
            ram[addr] <= din;
        rdreg <= ram[addr];
    end

    assign dout = rdreg;

endmodule

