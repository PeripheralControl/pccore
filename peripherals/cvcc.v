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

//////////////////////////////////////////////////////////////////////////
//
//  File: cvcc.v;   CVCC buck regulator controller
//
// Hardware Registers:
//   0,1:   vld     - Load voltage (high,low)
//   2,3:   ild     - Load current
//   4,5:           -
//   6,7    per     - Period of vld in units of 10 ns
//   8,9:   vset    - Maximum voltage to the load
//   10,11: iset    - Maximum current to the load
//   12:            - Enable
//
// Pins:
//   1  -- PWM output to control the FET
//   2  -- 
//   3  -- PWM input of load current
//   4  -- PWM input of load voltage
//
// INTRODUCTION:
//  This peripheral controls a cvcc buck regulator circuit.  The
//  circuit measures the load voltage and load current as a pulse width.
//  The period of the Vload signal is also reported to the host
//
/////////////////////////////////////////////////////////////////////////
module cvcc(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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
    inout  [3:0] pins;       // a PWM controlled SMPS
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [9:0] vset;       // Output Voltage
    reg    [9:0] iset;       // Output Current
    reg    [15:0] vld;       // Load voltage
    reg    [15:0] ild;       // Load current
    reg    [15:0] per;       // Measurement period
    reg    enabled;          // == 1 to enable FET and data up to the host
    reg    marked;           // ==1 if we need to send an auto-update to the host
    reg    [9:0] debcount;   // Debounce Vload input with this counter
    reg    [9:0] vldcount;   // PWM counter for Vin
    reg    [9:0] ildcount;   // PWM counter for Iin
    reg    [9:0] percount;   // count of 100ns pulses in period of vload
    reg    pinFET;           // Pin 1 with PWM of FET to control Vout
    reg    pinVld;           // Pin 2 with PWM of load voltage
    reg    pinIld;           // Pin 3 with PWM of load current
    reg    [9:0] pwmcount;   // drive the FET with a straight PWM 
    reg    [9:0] fetpwm;     // FET output is high if this is less than pwmcount


    initial
    begin
        pinFET = 0;
        pinIld = 0;
        pinVld = 0;
        vset = 0;
        iset = 0;
        enabled = 0;
        marked = 0;
        debcount = 0;
        vldcount = 0;
        ildcount = 0;
        percount = 0;
        vld = 0;
        ild = 0;
        per = 0;
        pwmcount = 0;
        fetpwm = 0;
    end

    always @(posedge CLK_I)
    begin
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[3:0] == 8)                 // high bits V out
                fetpwm[15:8] <= DAT_I[7:0];
            if (ADR_I[3:0] == 9)                 // low bits V out
                fetpwm[7:0]  <= DAT_I[7:0];
            if (ADR_I[3:0] == 10)                // high bits I out
                iset[9:8] <= DAT_I[1:0];
            if (ADR_I[3:0] == 11)                // low bits I out
                iset[7:0]  <= DAT_I[7:0];
            if (ADR_I[3:0] == 12)                // low bits I out
                enabled    <= DAT_I[0];          // enable flag
        end
        else if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
            marked <= 0;
        else if (clocks[`M10CLK])               // send to host every 10ms
            marked <= 1'b1;
            //marked <= enabled;
    end

    always @(posedge clocks[`N10CLK])
    begin
        // Capture input pins
        pinIld <=  pins[2];
        pinVld <=  pins[3];

        // Debounce the Vld line to use it as the PWM period clock
        if (pinVld == 1'b0)
        begin
            debcount <= 8'h00;            // reset debounce count
            ildcount <= (pinIld) ? (ildcount + 10'h001) : ildcount;
            percount <= percount + 10'h1;
        end
        else if (debcount != 8'h08)
        begin
            debcount <= debcount + 8'h01;
            vldcount <= (pinVld) ? (vldcount + 10'h001) : vldcount;
            ildcount <= (pinIld) ? (ildcount + 10'h001) : ildcount;
            percount <= percount + 10'h1;
        end
        else
        begin
            // At this point we have 8 values of 1 for Vld.  We use
            // this as the leading edge of the period for measuring
            // the PWM inputs.  The counts are cleared and added to
            // the totals to be sent to the host.
            debcount <= debcount + 8'h01;   // to nine and on up
            vldcount <= 10'h000;
            ildcount <= 10'h000;
            percount <= 10'h000;

            // Use an IIR to filter the raw values before sending to host
            ild <= (ild - {4'h0,(ild >> 4)}) + {6'h00,ildcount};
            vld <= (vld - {4'h0,(vld >> 4)}) + {6'h00,vldcount};
            per <= (per - {4'h0,(per >> 4)}) + {6'h00,percount};
        end

        // pinFET is a PWM output tied to Vout.
        pinFET <= (fetpwm >= pwmcount);
        pwmcount <= pwmcount + 10'h001;
    end


    // Assign the outputs.
    assign   pins[0] =  pinFET;
//assign   pins[4] = pinFET;
//assign   pins[5] = pwmcount[9];
//assign   pins[6] = 0;
//assign   pins[7] = 0;


    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & marked) ? 8'h08 :   // send up 8 bytes if data available
                     (TGA_I && (ADR_I[2:0] == 0)) ? vld[15:8] :
                     (TGA_I && (ADR_I[2:0] == 1)) ? vld[7:0] :
                     (TGA_I && (ADR_I[2:0] == 2)) ? ild[15:8] :
                     (TGA_I && (ADR_I[2:0] == 3)) ? ild[7:0] :
                     (TGA_I && (ADR_I[2:0] == 4)) ? 0 :
                     (TGA_I && (ADR_I[2:0] == 5)) ? 0 :
                     (TGA_I && (ADR_I[2:0] == 6)) ? per[15:8] :
                     (TGA_I && (ADR_I[2:0] == 7)) ? per[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule



