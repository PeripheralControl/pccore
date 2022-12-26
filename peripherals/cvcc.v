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
//   0,1:   vlin    - Load voltage (high,low)
//   2,3:   ilin    - Load current
//   4,5:   vref    - PWM width of Vref
//   6,7    per     - Period of Vref in units of 10 ns
//   8,9:   vset    - Maximum voltage to the load
//   10,11: iset    - Maximum current to the load
//   12:            - Enable
//
// Pins:
//   1  -- PWM output to control the FET
//   2  -- PWM input of 2.7 volt reference
//   3  -- PWM input of load current
//   4  -- PWM input of load voltage
//
// INTRODUCTION:
//  This peripheral controls a cvcc buck regulator circuit.  The
//  circuit measures the load voltage, load current, and a reference
//  PWM pulse corresponding to 2.7 volts.
//  The 2.7 volt reference defines the period of the PWM control to
//  the FET. 
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
    inout  [3:0] pins;       // Simple Bidirectional I/O 
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [9:0] vout;       // Output Voltage
    reg    [9:0] iout;       // Output Current
    reg    [15:0] vin;       // Load voltage
    reg    [15:0] iin;       // Load current
    reg    [15:0] ref;       // Measured positive PWM time for the voltage reference
    reg    [15:0] per;       // Measurement period
    reg    enabled;          // == 1 to enable FET and data up to the host
    reg    marked;           // ==1 if we need to send an auto-update to the host
    reg    [9:0] debcount;   // 2.7 ref input at debval for this many 10ns clocks
    reg    [9:0] vincount;   // PWM counter for Vin
    reg    [9:0] iincount;   // PWM counter for Iin
    reg    [9:0] refcount;   // Positive PWM counter for Vref
    reg    [9:0] percount;   // count of 100ns pulses in period of vref
    reg    pinFET;           // Pin 1 with PWM of FET to control Vout
    reg    pinVin;           // Pin 2 with PWM of load voltage
    reg    pinIin;           // Pin 3 with PWM of load current
    reg    pinVref;          // Pin 4 with PWM of 2.7 volt reference
reg    [9:0] pwmtestcount;// drive the FET with a straight PWM for testing


    initial
    begin
        pinFET = 0;
        pinVref = 0;
        pinIin = 0;
        pinVin = 0;
        vout = 0;
        iout = 0;
        enabled = 0;
        marked = 0;
        debcount = 0;
        vincount = 0;
        iincount = 0;
        refcount = 0;
        percount = 0;
        vin = 0;
        iin = 0;
        ref = 0;
        per = 0;
pwmtestcount = 0;
    end

    always @(posedge CLK_I)
    begin
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[3:0] == 8)                 // high bits V out
                vout[9:8] <= DAT_I[1:0];
            if (ADR_I[3:0] == 9)                 // low bits V out
                vout[7:0]  <= DAT_I[7:0];
            if (ADR_I[3:0] == 10)                // high bits I out
                iout[9:8] <= DAT_I[1:0];
            if (ADR_I[3:0] == 11)                // low bits I out
                iout[7:0]  <= DAT_I[7:0];
            if (ADR_I[3:0] == 12)                // low bits I out
                enabled    <= DAT_I[0];          // enable flag
        end
        else if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
            marked <= 0;
        else if (clocks[`M100CLK])               // send to host every 100ms
            marked <= enabled;
    end

    always @(posedge clocks[`N10CLK])
    begin
        // Capture input pins
        pinVref <= pins[1];
        pinIin <=  pins[2];
        pinVin <=  pins[3];

        // Debounce the Vref line to use it as the PWM period clock
        if (pinVref == 1'b0)
        begin
            debcount <= 8'h00;            // reset debounce count
            vincount <= (pinVin) ? (vincount + 10'h001) : vincount;
            iincount <= (pinIin) ? (iincount + 10'h001) : iincount;
            refcount <= (pinVref) ? (refcount + 10'h001) : refcount;
            percount <= percount + 10'h1;
        end
        else if (debcount != 8'h08)
        begin
            debcount <= debcount + 8'h01;
            vincount <= (pinVin) ? (vincount + 10'h001) : vincount;
            iincount <= (pinIin) ? (iincount + 10'h001) : iincount;
            refcount <= (pinVref) ? (refcount + 10'h001) : refcount;
            percount <= percount + 10'h1;
        end
        else
        begin
            // At this point we have 8 values of 1 for Vref.  We use
            // this as the leading edge of the period for measuring
            // the PWM inputs.  The counts are cleared and added to
            // the totals to be sent to the host.
            debcount <= debcount + 8'h01;   // to nine and on up
            vincount <= 10'h000;
            iincount <= 10'h000;
            refcount <= 10'h000;
            percount <= 10'h000;
            iin <= {6'h00,iincount};
            vin <= {6'h00,vincount};
            // Use an IIR to filter the raw values before sending to host
            iin <= (iin - {4'h0,(iin >> 4)}) + {6'h00,iincount};
            vin <= (vin - {4'h0,(vin >> 4)}) + {6'h00,vincount};
            ref <= (ref - {4'h0,(ref >> 4)}) + {6'h00,refcount};
            per <= (per - {4'h0,(per >> 4)}) + {6'h00,percount};
            // Compute the state of the FET control pin.  For the FET to
            // be on the system must be enabled and both the load current
            // and voltage must be below the user defined limits.
            //pinFET <= enabled && (vincount < vout) && (iincount < iout);
        end
        // (for now we force pinFET to be just a PWM output slaved 
        // to Vout.  This is useful for testing
        pwmtestcount <= pwmtestcount + 10'h001;
        pinFET <= (vout > pwmtestcount);
    end


    // Assign the outputs.
    assign   pins[0] =  pinFET;


    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & marked) ? 8'h08 :   // send up 6 bytes if data available
                     (TGA_I && (ADR_I[2:0] == 0)) ? vin[15:8] :
                     (TGA_I && (ADR_I[2:0] == 1)) ? vin[7:0] :
                     (TGA_I && (ADR_I[2:0] == 2)) ? iin[15:8] :
                     (TGA_I && (ADR_I[2:0] == 3)) ? iin[7:0] :
                     (TGA_I && (ADR_I[2:0] == 4)) ? ref[15:8] :
                     (TGA_I && (ADR_I[2:0] == 5)) ? ref[7:0] :
                     (TGA_I && (ADR_I[2:0] == 6)) ? per[15:8] :
                     (TGA_I && (ADR_I[2:0] == 7)) ? per[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


