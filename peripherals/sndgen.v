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
// *********************************************************

//////////////////////////////////////////////////////////////////////////
//
//  File: sndgen.v;   Simple 8 bit sound generator
//
//  Registers are
//    Addr=0    Oscillator mode in high 4 bits. High 4 bits of osc phase step
//    Addr=1    Oscillator phase step low byte.  One LSB=1.527 Hz
//    Addr=2    LFO oneshot, invert and mode. High 4 bits of LFO phase step 
//    Addr=3    LFO phase step low byte.
//    Addr=4    LFO period  (units of 0.01 sec)
//    Addr=5    LFO steps per update, Step size is 0.01 seconds
//    Addr=6    Bit7=osc enable, bit6=lfsr enable, bits  5-4 is lfsr clock, Bit 3-2
//              and 1-0 are attenuation where 00=none, 1=1/2, 2=1/4, and 3=1/8
//
// NOTES:
//
/////////////////////////////////////////////////////////////////////////
// oscillator modes
`define OSC_SQUARE    0
`define OSC_RAMP      1
`define OSC_TRIANGLE  2

module sndgen(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire m100clk =  clocks[`M100CLK];    // utility 100.0 millisecond pulse
    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse
    wire m1clk   =  clocks[`M1CLK];      // utility 1.000 millisecond pulse
    wire u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse
    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse
    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse
    wire n100clk =  clocks[`N100CLK];    // utility 100.0 nanosecond pulse
    wire n10clk  =  clocks[`N10CLK];     // utility 100.0 nanosecond pulse
 
    wire   myaddr;                 // ==1 if a correct read/write on our address

    // Sound input registers
    reg    osc_enable;             // ==1 to add osc to output
    reg    [1:0] osc_attn;         // oscillator attenuation
    reg    [1:0] osc_mode;         // triangle, ramp, square
    reg    osc_invert;             // invert the osc output
    reg    [11:0] osc_phstep;      // VCO phase step. LSB=1.527 Hz
    reg    oneshot;                // if 1 shut off output at end of lfo_period
    reg    lfo_invert;             // invert FLO output
    reg    [1:0] lfo_mode;         // triangle, ramp, square
    reg    [7:0] lfo_period;       // in units of 0.01 seconds
    reg    [7:0] lfo_steps;        // update phase every lfo_steps
    reg    [11:0] lfo_phstep;      // add phstep to phase every lfo_steps
    reg    lfsr_enable;            // ==1 to add lfsr to output
    reg    [1:0] lfsr_clk;         // 100KHz if set 1 KHz if clear
    reg    [1:0] lfsr_attn;        // noise attenuation
    // Sound generation registers
    reg    [15:0] osc_acc;         // osc  phase accumulator (16 bits)
    wire   [7:0] osc_waveform;     // oscillator waveform
    wire   [7:0] osc_out;          // oscillator output with enable and attenuation
    reg    output_enable;          // set by any write to peripheral, cleared by oneshot
    reg    [7:0] lfo_count;        // counts 0.01 secs of FLO period
    reg    [11:0] lfo_delta;       // delta phase adjustment from LFO
    reg    [7:0] stepcount;        // adjust LFO delta when stepcount==0
    reg    [15:0] lfsr;            // linear feedback shift register
    wire   [7:0] lfsr_out;         // high bits of the shift register
    wire   [7:0] sigout;           // mixed value of osc and noise


    initial
    begin
        osc_enable = 0;           // disabled
        osc_attn = 0;             // no attenuation
        osc_mode = `OSC_SQUARE;  
        osc_invert = 0;           // non-inverted
        osc_phstep = 0;
        output_enable = 0;
        oneshot = 0;              // repeat LFO waveform
        lfo_invert = 0;           // non-inverted
        lfo_mode = `OSC_SQUARE;   // triangle, ramp, square
        lfo_period = 0;           // units of 0.01 seconds (LFO is off)
        lfo_count = 0;
        lfo_delta = 0;
        stepcount = 0;
        lfo_steps = 0;            // update phase every lfo_steps
        lfo_phstep = 0;           // add phstep to phase every lfo_steps
        lfsr = 0;
        lfsr_enable = 0;          // disabled
        lfsr_clk = 0;
        lfsr_attn = 0;            // no attenuation
        osc_acc = 0;              // oscillator phase accumulator
    end

    always @(posedge CLK_I)
    begin
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            // Any write enables the output
            output_enable <= 1;

            // Adr=0  Osc mode in high 4 bits. High 4 bits of osc phase step
            if (ADR_I[3:0] == 0)
            begin
                osc_invert <= DAT_I[6];
                osc_mode <= DAT_I[5:4];           // osc waveform
                osc_phstep[11:8] <= DAT_I[3:0];
            end

            // Adr=1  Osc phase step low byte.  One LSB=1.527 Hz
            else if (ADR_I[3:0] == 1)             // osc frequency
                osc_phstep[7:0] <= DAT_I;

            // Adr=2  LFO invert, mode (bits 6-4). High 4 bits of LFO phase step 
            else if (ADR_I[3:0] == 2)
            begin
                oneshot <= DAT_I[7];
                lfo_invert <= DAT_I[6];
                lfo_mode <= DAT_I[5:4];           // lfo waveform
                lfo_phstep[11:8] <= DAT_I[3:0];
            end

            // Adr=3  LFO phase step low byte.
            else if (ADR_I[3:0] == 3)
                lfo_phstep[7:0] <= DAT_I;

            // Adr=4  LFO period  (units of 0.01 sec)
            else if (ADR_I[3:0] == 4)
                lfo_period <= DAT_I;

            // Adr=5  LFO steps per update, Update osc phase every X 0.01 seconds
            else if (ADR_I[3:0] == 5)
                lfo_steps <= DAT_I;               // phase update rate

            // Adr=6  OSC/LFSR enable and attenuation
            else if (ADR_I[3:0] == 6)
            begin
                osc_enable <= DAT_I[7];
                lfsr_enable <= DAT_I[6];
                lfsr_clk <= DAT_I[5:4];
                osc_attn <= DAT_I[3:2];
                lfsr_attn <= DAT_I[1:0];
            end
        end

        if (u10clk)     // audio processing runs at 100 KHz
        begin
           if (lfo_invert)   // ramping down or up?
               osc_acc <= osc_acc + {4'h0, osc_phstep} - {4'h0, lfo_delta};
           else
               osc_acc <= osc_acc + {4'h0, osc_phstep} + {4'h0, lfo_delta};
        end

        if ((u10clk & (lfsr_clk == 2'h2)) || (u100clk & (lfsr_clk == 2'h1)) ||
            (m1clk & (lfsr_clk == 2'h0)))
        begin
           // lfsr polynomial d295 gives 65535 unique values before repeating
           if (lfsr == 0)
               lfsr <= 5;     // start up seed
           else
               lfsr <= (lfsr[0]) ? (lfsr >> 1) ^ 16'hd295 : (lfsr >> 1);
        end

        if (m10clk && output_enable)     // LFO runs at 100 Hz
        begin
           if (lfo_count == lfo_period)    // LFO period in units of 0.01 seconds
           begin
               lfo_count <= 8'h0;
               lfo_delta <= 0;
               stepcount <= 0;
               if (oneshot)
               begin
                   output_enable <= 0;
                   osc_acc <= 0;
               end
           end
           else
           begin
               lfo_count <= lfo_count + 1;
               if (stepcount == lfo_steps)
               begin
                   stepcount <= 0;
                   // decrement delta if second half of a triangle LFO
                   if ((lfo_mode == `OSC_TRIANGLE) && (lfo_count > (lfo_period >> 1)))
                       lfo_delta <= lfo_delta - lfo_phstep;
                   else
                       lfo_delta <= lfo_delta + lfo_phstep;
               end
               else
                   stepcount <= stepcount +1;
            end
        end

    end


    // Get oscillator waveform, attenuation, and enable
    assign osc_waveform = 
        (osc_mode == `OSC_SQUARE) ? {8{osc_acc[15]}} :
        ((osc_mode == `OSC_RAMP) & (~osc_invert)) ? osc_acc[15:8] :
        ((osc_mode == `OSC_RAMP) & (osc_invert)) ? ~osc_acc[15:8] :  // else triangle
        ((osc_acc[15]) ? (~osc_acc[15:8] << 1) : (osc_acc[15:8] << 1) );
    assign osc_out = (~osc_enable) ? 8'h0 : (osc_waveform >> osc_attn);

    // Get noise soure, attenuation, and enable
    assign lfsr_out = (~lfsr_enable) ? 8'h0 : (lfsr[15:8] >> lfsr_attn);

    // Mixer            
    assign sigout = (~output_enable) ? 8'h0 : osc_out - lfsr_out;

    // Assign the outputs.
    assign pins =  sigout[7:5];

    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                     (TGA_I && (ADR_I[0] == 0)) ? 8'h00 :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


