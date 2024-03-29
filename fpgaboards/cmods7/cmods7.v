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
//  Note that while called "board.v" in the build system the host peripheral
//  has a name to match the board in use.  This gives the host access to the
//  board-specific features such as buttons and LEDs if they are on the
//  board.
//
//////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////
//
//  Board registers for the Digilent CmodS7
//
//  Reg 0: Button 0-1.  Read-only, 8 bit.  Auto-send on change.
//  Reg 1: RGB LED.  RGB in bits 2/1/0
//
//  Reg 64-95: Sixteen 16-bit driver IDs
//
/////////////////////////////////////////////////////////////////////////
module cmods7(CLK_O,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,BRDIO,PCPIN);
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
    reg    [1:0] btn0;       // bring buttons into our clock domain
    reg    [1:0] btn1;       // bring buttons into our clock domain
    reg    data_ready;       // ==1 if we have new data to send up to the host
    wire   [15:0] perid;     // ID of peripheral in core specified by ADR_I 
    perilist periids(ADR_I[4:1], perid);
    wire   n10clk;           // ten nanosecond clock
    reg    [2:0] rgbreg;     // RGB LEDs
    reg    [3:0] ledreg;     // image/copy of the pins on Slot #0

    initial
    begin
        btn0 = 0;
        btn1 = 0;
        rgbreg = 0;
        ledreg = 0;
        data_ready = 0;
    end


    // The board clock is already at 100 MHz.  (nice!)
    // Use it to generate the rest of the clocks.
    ck12to100 ck12to100inst(BRDIO[`BRD_CLOCK], n10clk);
    clocks gensysclks(n10clk, CLK_O, clocks);


    // Bring the Buttons into our clock domain.
    always @(posedge CLK_O)
    begin

        // clear data_ready register on a read
        if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
        begin
            data_ready <= 0;
        end

        // latch RGB data from host
        else if (TGA_I & myaddr & WE_I & (ADR_I[0] == 1'b1))
        begin
            rgbreg <= DAT_I[2:0];
        end

        // edge detection for sending buttons up to the host
        else if (clocks[`M10CLK])
        begin
            btn0 <= BRDIO[`BRD_BTN_1:`BRD_BTN_0];
            btn1 <= btn0;

            // edge detection
            if (btn0 != btn1)
            begin
                data_ready <= 1;
            end
        end

        // Copy Slot #1 pin values to the LEDs
        ledreg <= PCPIN[3:0];
    end
 

    // data out is the button if a read on us, our data ready send command 
    // if a poll from the bus interface, and data_in in all other cases.
    assign myaddr = (STB_I) && (ADR_I[7] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & data_ready) ? 8'h01 :   // send up one byte if data available
                     (TGA_I && (ADR_I[6] == 0) && (ADR_I[0] == 2'h0)) ? {6'h0,btn0[1:0]} :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 0)) ? perid[15:8] :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 1)) ? perid[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

    // Set the Slot1 monitor LEDs and the RGB LEDs.
    assign BRDIO[`BRD_LED_3:`BRD_LED_0] = ledreg;
    assign BRDIO[`BRD_RED_LED:`BRD_BLU_LED] = ~rgbreg; // LEDs are inverted

endmodule



module ck12to100 (ck12, ck100);
    input  ck12;   // 12 MHz board clock
    output ck100;  // 100 MHz clock
    wire   ckfb;   // feedback line

  MMCME2_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (1),
    .CLKFBOUT_MULT_F      (62.500),
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (7.500),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKIN1_PERIOD        (83.333))
  mmcm_adv_inst (
    .CLKFBOUT            (ckfb),
    .CLKOUT0             (ck100),
    .CLKFBIN             (ckfb),
    .CLKIN1              (ck12));

endmodule
