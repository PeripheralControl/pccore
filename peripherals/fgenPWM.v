// *********************************************************
// Copyright (c) 2026 Demand Peripherals, Inc.
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
// *********************************************************

//////////////////////////////////////////////////////////////////////////
//
//  File: fgen.v;   Simple 8 bit function generator
//
//  Fgen is a simple 2 MHz 8-bit function generator that can generate
//  sine, triangle, and square wave outputs.  All outputs types can be
//  asymmetric.  Fgen uses 8 FPGA pins and is intended to drive an R-2R
//  digital to analog converter.
//
//  Fgen uses a 32 bit phase accumulator with an update rate of 100 MHz.
//  Asymmetric output is achieved by having two phase offsets, one for
//  use while the phase MSB is zero and one for use while the phase MSB is
//  one.  The higher level application must use the desired symmetry and
//  desired frequency to computer the two phase increments.  The phase
//  offsets are 31 bits to guarantee that the MSB will alternate before
//  rolling over to a new cycle.
//
//  The high eight bits of the phase accumulator drive the output.  The high
//  byte goes to a sine look-up table for sine output.  The high byte value
//  is modified and sent directly to the output pin for triangle and square
//  wave outputs.
//
//  For the PWM version of fgen:
//  The low output pins is driven by an 8 bit PWM of the output.
//  The next low output is driven by a first order delta sigma.
//  The two high bits are driven by the MSBs of the phase accumulator.
//
//  Registers:
//      0:  Mode in low two bits:
//          0 -- off
//          1 -- sine
//          2 -- triangle
//          3 -- square
//      1:  low byte of rising 31 bit phase offset
//      2:  low mid byte of rising 31 bit phase offset
//      3:  high mid byte of rising 31 bit phase offset
//      4:  high byte of rising 31 bit phase offset
//      5:  low byte of falling 31 bit phase offset
//      6:  low mid byte of falling 31 bit phase offset
//      7:  high mid byte of falling 31 bit phase offset
//      8:  high byte of falling 31 bit phase offset
//
// NOTES:
//   Keeping the high bytes of the phase offsets clear gives the best output
//  precision since doing so makes full use of the 256 locations in the sine
//  lookup table.  Frequencies above 390 KHz will need to use the high byte
//  of the phase offsets.
//
/////////////////////////////////////////////////////////////////////////
// oscillator modes
`define OSC_OFF       0
`define OSC_SINE      1
`define OSC_TRIANGLE  2
`define OSC_SQUARE    3

module fgenPWM(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire   myaddr;                 // ==1 if a correct read/write on our address

    // State registers
    reg    [1:0] osc_mode;         // off, sine, triangle, square
    reg    [30:0] risingoffset;    // phase step for first half of cycle
    reg    [30:0] fallingoffset;   // phase step for second half of cycle
    reg    [31:0] phase;           // phase accumulator
    wire   [7:0] sine_val;         // value from sine lookup table
    wire   [7:0] fgenout;          // value as input to the DAC
    reg    [8:0] sigmasum;         // sum with carry (bit 8) driving the output pins
    reg    [7:0] pwmcount;
 

    initial
    begin
        osc_mode = `OSC_SQUARE;    // default is a 1 KHz square wave
        risingoffset = 31'h0000a202;
        fallingoffset = 31'h0000a202;
        phase = 0;
    end

    waveform_tablePWM waveform (clocks[`N10CLK], 1'h0, phase[31:24], 8'h0, sine_val);

    always @(posedge CLK_I)
    begin
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            // Adr=0  Osc mode in low 2 bits
            if (ADR_I[3:0] == 0)
            begin
                osc_mode <= DAT_I[1:0];           // osc waveform
            end

            // Adr=1-3  Rising phase step
            else if (ADR_I[3:0] == 1)             // low byte of rising offset
                risingoffset[7:0] <= DAT_I;
            else if (ADR_I[3:0] == 2)
                risingoffset[15:8] <= DAT_I;
            else if (ADR_I[3:0] == 3)
                risingoffset[23:16] <= DAT_I;
            else if (ADR_I[3:0] == 4)
                risingoffset[30:24] <= DAT_I[6:0];

            // Adr=4-6  Rising phase step
            else if (ADR_I[3:0] == 5)             // low byte of falling offset
                fallingoffset[7:0] <= DAT_I;
            else if (ADR_I[3:0] == 6)
                fallingoffset[15:8] <= DAT_I;
            else if (ADR_I[3:0] == 7)
                fallingoffset[23:16] <= DAT_I;
            else if (ADR_I[3:0] == 8)
                fallingoffset[30:24] <= DAT_I[6:0];
        end
    end

    // Update the phase every 10 nanoseconds
    always @(posedge clocks[`N10CLK])
    begin
        phase <= phase + ((phase[31] == 0) ? risingoffset : fallingoffset);
        sigmasum <= {1'b0,sigmasum[7:0]} + {1'b0,fgenout};
        pwmcount <= pwmcount + 1'b1;
    end

    // Assign the output based on waveform type
    assign fgenout = 
        (osc_mode == `OSC_OFF) ? 8'h00 :
        (osc_mode == `OSC_SQUARE) ? {8{phase[31]}} :
        (osc_mode == `OSC_TRIANGLE) ? (phase[31] ? ~phase[30:23] : phase[30:23]) :
        (sine_val) ;

    assign pins[0] = (fgenout > pwmcount) ? 1 : 0;
    assign pins[1] = sigmasum[8];
    assign pins[2] = phase[30];
    assign pins[3] = phase[31];

    // Assign peripheral outputs
    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 8'h00;   // no output registers

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


// Waveform lookup table preloaded with sine.
// This could be modified to be writable by the user.
module waveform_tablePWM (clk, we, addr, din, dout);
    input clk;
    input we;
    input [7:0] addr;
    input [7:0] din;
    output [7:0] dout;

    reg [7:0] wavetable [255:0];
    reg [7:0] dout;
    integer i;

initial
begin
    for (i=0; i < 256; i = i + 1) 
    begin
        wavetable[i] = (128.0 * $sin(i * 2 * 3.1415926 / 256.0) + 127.5);
    end
end

always @(posedge clk)
begin
    if (we)
        wavetable[addr] <= din;
    dout <= wavetable[addr];
end


endmodule


