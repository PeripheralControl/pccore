// *********************************************************
// Copyright (c) 2026 Bob Smith
// 
// THE SOFTWARE IS PROVIDED "AS IS," WITHOUT WARRANTIES OR
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
//  Peripherals for the Tang Primer 25K FPGA card
//  Reg 00: Button status in bit 0 and 1.
//  Reg 64: Table of sixteen 16-bit peripherals ID numbers
//
/////////////////////////////////////////////////////////////////////////
module tang25k(CLK_O,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,BRDIO,PCPIN);
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
    wire   ck50mhz;          // 50 MHz clock for PLL debugging
    reg    [1:0] hist1;      // current values of the user buttons
    reg    [1:0] hist2;      // past values of the user buttons
    reg    data_ready;       // New button values to send to host


    // Convert the 50 MHz clock to 100 MHz.
    assign ck50mhz = BRDIO[`BRD_CLOCK];
    CK50to100 ck50to100(ck100mhz, ck50mhz);
    clocks gensysclks(ck100mhz, CLK_O, clocks);

    // Bring the keys into our clock domain.
    always @(posedge CLK_O)
    begin
        hist1 <= BRDIO[`BRD_KEY2:`BRD_KEY1];
        hist2 <= hist1;


        // clear data_ready register on a read
        if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
            data_ready <= 0;

        // edge detection for sending data up to the host
        else if (hist1 != hist2)
        begin
            data_ready <= 1;
        end
    end


    // data out is the button if a read on us, our data ready send command 
    // if a poll from the bus interface, and data_in in all other cases.
    assign myaddr = (STB_I) && (ADR_I[7] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & data_ready) ? 8'h01 :   // send up one byte if data available
                     (TGA_I && (ADR_I[6] == 0)) ? {6'h00,hist1} :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 0)) ? perid[15:8] :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 1)) ? perid[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


// Use a PLL to convert the 50 MHz board clock to 100 MHz
module CK50to100 (clkout, clkin);

output clkout;
input clkin;

wire clkfbout_o;
wire [7:0] mdrdo_o;
wire gw_gnd;

assign gw_gnd = 1'b0;

PLLA PLLA_inst (
    .LOCK(lock),
    .CLKOUT0(clkout),
    .CLKFBOUT(clkfbout_o),
    .MDRDO(mdrdo_o),
    .CLKIN(clkin),
    .CLKFB(gw_gnd),
    .RESET(gw_gnd),
    .PLLPWD(gw_gnd),
    .RESET_I(gw_gnd),
    .RESET_O(gw_gnd),
    .PSSEL({gw_gnd,gw_gnd,gw_gnd}),
    .PSDIR(gw_gnd),
    .PSPULSE(gw_gnd),
    .SSCPOL(gw_gnd),
    .SSCON(gw_gnd),
    .SSCMDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .SSCMDSEL_FRAC({gw_gnd,gw_gnd,gw_gnd}),
    .MDCLK(gw_gnd),
    .MDOPC({gw_gnd,gw_gnd}),
    .MDAINC(gw_gnd),
    .MDWDI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd})
);

//VCO frequency 'FCLKIN*FBDIV_SEL*(MDIV_SEL+MDIV_FRAC_SEL/8)/IDIV_SEL'
//     1000  =  (50 * 4 * 10) / 2
//     1000 / ODIV0_SEL = 100 MHz
defparam PLLA_inst.FCLKIN = "50";
defparam PLLA_inst.IDIV_SEL = 2;
defparam PLLA_inst.FBDIV_SEL = 4;
defparam PLLA_inst.CLKFB_SEL = "INTERNAL";
defparam PLLA_inst.ODIV0_SEL = 10;
defparam PLLA_inst.MDIV_SEL = 10;
defparam PLLA_inst.MDIV_FRAC_SEL = 0;
defparam PLLA_inst.CLKOUT0_EN = "TRUE";
defparam PLLA_inst.CLKOUT0_DT_DIR = 1'b1;
defparam PLLA_inst.CLK0_IN_SEL = 1'b0;
defparam PLLA_inst.CLK0_OUT_SEL = 1'b0;
defparam PLLA_inst.CLKOUT0_PE_COARSE = 0;
defparam PLLA_inst.CLKOUT0_PE_FINE = 0;
defparam PLLA_inst.DYN_DPA_EN = "FALSE";
defparam PLLA_inst.DYN_PE0_SEL = "FALSE";
defparam PLLA_inst.RESET_I_EN = "FALSE";
defparam PLLA_inst.RESET_O_EN = "FALSE";
defparam PLLA_inst.ICP_SEL = 6'bXXXXXX;
defparam PLLA_inst.LPF_RES = 3'bXXX;
defparam PLLA_inst.LPF_CAP = 2'b00;
defparam PLLA_inst.SSC_EN = "FALSE";
defparam PLLA_inst.CLKOUT0_DT_STEP = 0;
endmodule
