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
//  File: board.v;   Host access to the FPGA board-specific peripherals.
//
//  This file is part of the glue that ties an FPGA board to the Peripheral
//  Controller bus and peripherals.  It serves the following functions:
//  - Host access to the driver ID list 
//  - Generates clocks from 100 MHz to 1 Hz.
//  - Host access to buttons and LEDs as appropriate
//  - Host access to configuration memory if available
//
//////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////
//  Peripherals for the Runber FPGA card.
//  Reg 0-1: Switches and buttons.  Read-only.  Auto-send on change.
//  Reg 2-3: RGB LEDs.  Read/write, red/green/blue
//  Reg 4-7: Segment values for display #1-4
//  Reg 64: Table of sixteen 16-bit peripherals ID numbers
//
/////////////////////////////////////////////////////////////////////////
module runber(CLK_O,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,BRDIO,PCPIN);
    output CLK_O;            // system clock
    input  WE_I;             // direction of this transfer. Read=0; Write=1
    input  TGA_I;            // ==1 if reg access, ==0 if poll
    input  STB_I;            // ==1 if this peri is being addressed
    input  [7:0] ADR_I;      // address of target register
    output STALL_O;          // ==1 if we need more clk cycles to complete
    output ACK_O;            // ==1 if we claim the above address
    input  [7:0] DAT_I;      // Data INto the peripheral;
    output [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    output [`MXCLK:0] clocks; // Array of clock pulses from 10ns to 1 second
    inout  [`BRD_MX_IO:0]  BRDIO;     // Board IO 
    inout  [`MX_PCPIN:0]   PCPIN;     // Peripheral Controller Pins (for Pmods)
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [15:0] perid;     // ID of peripheral in core specified by ADR_I 
    perilist periids(ADR_I[4:1], perid);
    wire   ck100mhz;         // 100 MHz clock
    reg    [7:0] leds;       // Must latch input for display on LEDs
    reg    [15:0] btn0;      // bring buttons and switches into our clock domain
    reg    [15:0] btn1;      // switches are low four bits.  
    reg    data_ready;       // ==1 if we have new data to send up to the host
    reg    [3:0] red;        // Red for the four RGB LEDs
    reg    [3:0] green;      // Green for the four RGB LEDs
    reg    [3:0] blue;       // Blue for the four RGB LEDs
    reg    [7:0] segs[3:0];  // Array of segment values
    reg    [1:0] digit;      // Counter to specify displayed digit


    // Convert the 12 MHz clock to 100 MHz.
    CK12to100 ck12to100(ck100mhz, BRDIO[`BRD_CLOCK]);
    clocks gensysclks(ck100mhz, CLK_O, clocks);


    initial              // Not synthesized.  Used in simulation
    begin
        btn0 = 16'h0;
        btn1 = 16'h0;
        data_ready = 0;
    end

    always @(posedge CLK_O)
    begin
        // Leds follow pins in the first two slots
        leds <= PCPIN[7:0];

        // Latch RGB LED values from host
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[2:0] == 3'h2)
                red <= DAT_I[3:0];    // Red RGB LEDs
            if (ADR_I[2:0] == 3'h3)
            begin
                green <= DAT_I[7:4];  // Green RGB LEDs
                blue <= DAT_I[3:0];   // Blue RGB LEDs
            end
            if (ADR_I[2] == 1'h1)
                segs[ADR_I[1:0]] <= DAT_I;
        end

        // Latch switches, clear data_ready on read, do edge detection
        btn0 <= BRDIO[`BRD_BTN_7:`BRD_SW_0];
        btn1 <= btn0;
        if (TGA_I & myaddr & ~WE_I)
            data_ready <= 0;
        else if ((btn1 != btn0) & ~data_ready)
        begin
            data_ready <= 1;
        end

        // Switch from one seven segment digit to the next ever millisecond
        if (clocks[`M1CLK])
        begin
            digit <= digit + 2'h1;
        end
    end


    // data out is the button if a read on us, our data ready send command 
    // if a poll from the bus interface, and data_in in all other cases.
    assign myaddr = (STB_I) && (ADR_I[7] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & data_ready) ? 8'h02 :   // send up two byte if data is ready
                     (TGA_I && (ADR_I[6] == 0) && (ADR_I[0] == 0)) ? ~btn0[15:8] : // btns inverted
                     (TGA_I && (ADR_I[6] == 0) && (ADR_I[0] == 1)) ? btn0[7:0] :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 0)) ? perid[15:8] :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 1)) ? perid[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

    // Connect first two peripheral ports to board LEDs
    assign BRDIO[`BRD_LED_7:`BRD_LED_0] = leds;  // drive low to light

    // Connect the rgb register to the output pins
    assign BRDIO[`BRD_RED3:`BRD_RED0] = ~red;
    assign BRDIO[`BRD_GRN3:`BRD_GRN0] = ~green;
    assign BRDIO[`BRD_BLU3:`BRD_BLU0] = ~blue;

    // Set the segment and digit driver pins
    assign BRDIO[`BRD_SEG_DP:`BRD_SEG_A] = segs[digit];
    assign BRDIO[`BRD_DGT_3:`BRD_DGT_0] = (digit == 2'h0) ? 4'b1110 :
                                          (digit == 2'h1) ? 4'b1101 :
                                          (digit == 2'h2) ? 4'b1011 : 4'b0111 ;
endmodule


// Use a PLL to convert the 12 MHz board clock to 100 MHz
module CK12to100 (clkout, clkin);
output clkout;      // 100 MHz
input  clkin;       // board clock at 12 MHz


rPLL rpll_inst (
    .CLKOUT(clkout),
    .CLKIN(clkin),
    .CLKFB(0),
    .FBDSEL({0,0,0,0,0,0}),
    .IDSEL({0,0,0,0,0,0}),
    .ODSEL({0,0,0,0,0,0}),
    .PSDA({0,0,0,0}),
    .DUTYDA({0,0,0,0}),
    .FDLY({0,0,0,0})
);

defparam rpll_inst.FCLKIN = "12";
defparam rpll_inst.DYN_IDIV_SEL = "false";
defparam rpll_inst.IDIV_SEL = 2;
defparam rpll_inst.DYN_FBDIV_SEL = "false";
defparam rpll_inst.FBDIV_SEL = 24;
defparam rpll_inst.DYN_ODIV_SEL = "false";
defparam rpll_inst.ODIV_SEL = 8;
defparam rpll_inst.PSDA_SEL = "0000";
defparam rpll_inst.DYN_DA_EN = "true";
defparam rpll_inst.DUTYDA_SEL = "1000";
defparam rpll_inst.CLKOUT_FT_DIR = 1'b1;
defparam rpll_inst.CLKOUTP_FT_DIR = 1'b1;
defparam rpll_inst.CLKOUT_DLY_STEP = 0;
defparam rpll_inst.CLKOUTP_DLY_STEP = 0;
defparam rpll_inst.CLKFB_SEL = "internal";
defparam rpll_inst.CLKOUT_BYPASS = "false";
defparam rpll_inst.CLKOUTP_BYPASS = "false";
defparam rpll_inst.CLKOUTD_BYPASS = "false";
defparam rpll_inst.DYN_SDIV_SEL = 2;
defparam rpll_inst.CLKOUTD_SRC = "CLKOUT";
defparam rpll_inst.CLKOUTD3_SRC = "CLKOUT";
defparam rpll_inst.DEVICE = "GW1N-4D";

endmodule

