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
//  File: dgspi.v;   Digilent compatible SPI interface
//
//  Registers are
//    Addr=0    Clock select, chip select control, interrupt control and
//              SPI mode register
//    Addr=1    Poll timer.  Send most recent pkt every polltime * 0.01 sec
//              Disable if polltime is zero.
//    Addr=2    FIFO: Size of packet as the first byte followed
//              all the data bytes
//
//
/////////////////////////////////////////////////////////////////////////

// Copied from sysdefs.h
//  SPI states and configuration definitions.
//`define IDLE         3'h0
//`define GETBYTE      3'h1
//`define LOWBYTE      3'h2
//`define SNDBYTE      3'h3
//`define SNDRPLY      3'h4
//`define CS_MODE_AL   2'h0   // Active low chip select
//`define CS_MODE_AH   2'h1   // Active high chip select
//`define CS_MODE_FL   2'h2   // Forced low chip select
//`define CS_MODE_FH   2'h3   // Forced high chip select
//`define CLK_2M       2'h0   // 2 MHz
//`define CLK_1M       2'h1   // 1 MHz
//`define CLK_500K     2'h2   // 500 KHz
//`define CLK_100K     2'h3   // 100 KHz


module dgspi(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
    localparam LGMXPKT = 6;  // Log of maximum pkt size
    localparam MXPKT = (LGMXPKT ** 2);   // Maximum pkt size (= our buffer size)
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
    inout  [3:0] pins;       // FPGA I/O pins


    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [7:0] dout;       // RAM output lines
    wire   [LGMXPKT-1:0] raddr;      // RAM address lines
    wire   [7:0] din;        // RAM input lines
    wire   wclk;             // RAM write clock
    wire   wen;              // RAM write enable
    wire   smclk;            // The SPI state machine clock
    wire   cs;               // CS 
    wire   rawmosi;          // MOSI from the RAM before latching
    reg    [1:0] clksrc;     // SCK clock frequency (2,1,.5,.1 MHz)
    reg    [1:0] csmode;     // Chip select mode of operation
    reg    [LGMXPKT:0] sndcnt;     // Number of bytes in the SPI pkt 
    reg    meta;             // Used to bring miso into our clock domain
    reg    [6:0] clkpre;     // clock prescaler
    reg    [2:0] state;      // idle, getting bytes, lowbyte, sending bytes, sending response
    reg    [LGMXPKT:0] bytcnt;     // counter for getting and sending bytes
    reg    [3:0] bitcnt;     // bit counter for shift register
    reg    int_en;           // Interrupt enable. 1==enabled
    reg    int_pol;          // Interrupt polarity, 1==int pending if MISO is high while CS=0
    reg    int_pend;         // We've sent an interrupt packet, no need to send another
    reg    rawsck;           // ungated SCK clock
    wire   sck;              // gates SCK to the output
    reg    mosi;
    reg    sckpol;           // polarity of SCK.
    reg    [7:0] polltime;   // User set time between automatic poll of the device
    reg    [7:0] pollcnt;    // Count of 10ms clocks. Poll when it reaches polltime
    wire   m10clk = clocks[`M10CLK];     // utility 10.00 millisecond pulse

    assign pins[0] = cs;     // SPI chip select
    assign pins[1] = mosi;   // SPI Master Out / Slave In
    wire   miso = pins[2];   // SPI Master In / Slave Out
    assign pins[3] = sck;    // SPI SCK

    initial
    begin
        clksrc = `CLK_1M;
        csmode = `CS_MODE_AL;
        state = `IDLE;
        sndcnt = 0;
        meta = 0;
        clkpre = 0;
        state = 0;
        bytcnt = 0;
        bitcnt = 0;
        int_en = 0;
        int_pol = 0;
        int_pend = 0;
        rawsck = 0;
        sckpol = 0;
        polltime = 0;
        pollcnt = 0;
    end


    // Register array in RAM
    dgspiram16x8 #(.LGDEPTH(LGMXPKT)) spipkt(dout,raddr,din,wclk,wen);

    // Generate the state machine clock for the SPI interface
    assign smclk = (clkpre == 0) & rawsck;

    always @(posedge CLK_I)
    begin
        // Bring MISO into our clock domain
        meta <= miso;

        // Do frequency division for sck
        clkpre <= (clksrc[1:0] == `CLK_2M) & (clkpre == 4) ? 0 :
                  (clksrc[1:0] == `CLK_1M) & (clkpre == 9) ? 0 :
                  (clksrc[1:0] == `CLK_500K) & (clkpre == 19) ? 0 :
                  (clksrc[1:0] == `CLK_100K) & (clkpre == 99) ? 0 :
                  clkpre + 1;

        rawsck <= (clkpre == 0) ? ~rawsck : rawsck;
        if ((clkpre == 1) && (rawsck == 0))
            mosi <= rawmosi & (bytcnt < (sndcnt -1));

        // Handle write and read requests from the host
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[LGMXPKT-1:0] == 0)         // a config write
            begin
                clksrc <= DAT_I[7:6];
                int_en <= DAT_I[5];
                int_pol <= DAT_I[4];
                csmode <= DAT_I[3:2];
                sckpol <= DAT_I[1];
                state <= `IDLE;
            end
            else if (ADR_I[LGMXPKT-1:0] == 1)    // set poll time
            begin
                polltime <= DAT_I;
            end
            else if (ADR_I[LGMXPKT-1:0] == 2)    // a fifo write 
            begin
                // state will be IDLE on the first byte into the fifo.  This
                // is the size of the packet to send
                if (state == `IDLE)
                begin
                    sndcnt <= DAT_I[LGMXPKT:0];
                    bytcnt <= 0;
                    state <= `GETBYTE;
                end
            end
            else
            begin
                // Getting bytes from the host.  Send SPI pkt when done
                if ((bytcnt + 2) == sndcnt)
                begin
                    state <= `LOWBYTE;
                    bitcnt <= 0;
                end
                else
                begin
                    bytcnt <= bytcnt + 1;
                end
            end
        end
        else if (TGA_I & myaddr )  // back to idle after the reply pkt read
        begin
            // Auto send reads from consecutive locations starting at zero.
            // There is no autosend fifo read.  We spoof this by ignoring the
            // address requested and responding with the ram data at location
            // ram[bytcnt].
            state <= `IDLE;
            bytcnt <= bytcnt + 1;
        end

        // Check for a poll timeout, send out pkt if timeout and idle
        else if (m10clk && (polltime != 0))
        begin
            pollcnt <= pollcnt - 8'h1;
            if (pollcnt == 0)
            begin
                pollcnt <= polltime;
                if (state == `IDLE)
                    state <= `LOWBYTE;
            end
        end

        // Do the state machine to shift in/out the SPI data if sending and on clk edge
        else if (smclk && ((state == `SNDBYTE) || (state == `LOWBYTE)))
        begin
                if (bitcnt == 9)
                begin
                    bitcnt <= 0;
                    // Low byte is a one-byte period just after CS goes low to give the
                    // target device a chance to come out of reset.  Just one byte period
                    // so we immediately go into SNDBYTE
                    if (state == `LOWBYTE)
                    begin
                        state <= `SNDBYTE;
                        bytcnt <= 0;
                    end
                    else
                    begin
                        if ((bytcnt +1) == sndcnt)
                        begin
                            state <= `SNDRPLY;
                            bytcnt <= 0;    // reset to start for the autosend read
                        end
                        else
                            bytcnt <= bytcnt + 1;
                    end
                end
                else
                begin
                    bitcnt <= bitcnt + 4'h1;
                end
        end 
        // set the interrupt pending flag just as we start the 1 byte transmission
        // to the host.  This way only one packet is sent
        if (myaddr & ~TGA_I & (state ==`IDLE) & (miso == int_pol) & (int_en) & (~int_pend))
        begin
            int_pend <= 1;
        end
        if(myaddr & ~TGA_I & (state == `SNDRPLY) & (int_pend))
        begin
            // Clear the interrupt pending flag on any data to host
            int_pend <= 0;
        end
    end


    // Assign the outputs.
    assign cs = (csmode == `CS_MODE_AL) ? ~((state == `SNDBYTE) | (state == `LOWBYTE)) :
                (csmode == `CS_MODE_AH) ? ((state == `SNDBYTE) | (state == `LOWBYTE)) :
                (csmode == `CS_MODE_FH) ? 1'b1 : 1'b0;
    assign sck = sckpol ^ ((state == `SNDBYTE) & (bitcnt < 8) & rawsck & (bytcnt < (sndcnt -1)));
    assign rawmosi = ((dout[0] & (bitcnt == 7)) |
                      (dout[1] & (bitcnt == 6)) |
                      (dout[2] & (bitcnt == 5)) |
                      (dout[3] & (bitcnt == 4)) |
                      (dout[4] & (bitcnt == 3)) |
                      (dout[5] & (bitcnt == 2)) |
                      (dout[6] & (bitcnt == 1)) |
                      (dout[7] & (bitcnt == 0))) ;


    // Assign the RAM control lines
    assign wclk  = CLK_I;
    assign wen   = (state == `GETBYTE) ? (TGA_I & myaddr & WE_I) :
                   ((state ==`SNDBYTE) & (bitcnt < 8) ) ;
    assign din[0] = (state != `SNDBYTE) ? DAT_I[0] : (bitcnt == 7) ? meta : dout[0];
    assign din[1] = (state != `SNDBYTE) ? DAT_I[1] : (bitcnt == 6) ? meta : dout[1];
    assign din[2] = (state != `SNDBYTE) ? DAT_I[2] : (bitcnt == 5) ? meta : dout[2];
    assign din[3] = (state != `SNDBYTE) ? DAT_I[3] : (bitcnt == 4) ? meta : dout[3];
    assign din[4] = (state != `SNDBYTE) ? DAT_I[4] : (bitcnt == 3) ? meta : dout[4];
    assign din[5] = (state != `SNDBYTE) ? DAT_I[5] : (bitcnt == 2) ? meta : dout[5];
    assign din[6] = (state != `SNDBYTE) ? DAT_I[6] : (bitcnt == 1) ? meta : dout[6];
    assign din[7] = (state != `SNDBYTE) ? DAT_I[7] : (bitcnt == 0) ? meta : dout[7];
    assign raddr = bytcnt[LGMXPKT-1:0];

    // Assign the bus control lines
    assign myaddr = (STB_I) && (ADR_I[7:LGMXPKT] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                    (~TGA_I & (state == `SNDRPLY)) ? {{(8-LGMXPKT) {1'b0}}, sndcnt} :
                    // send one byte if device is requesting service/interrupt
                    (~TGA_I & (state ==`IDLE) & (miso == int_pol) & (int_en) & (~int_pend)) ? 8'h01 :
                    (TGA_I) ? dout :
                    8'h00 ; 
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


module dgspiram16x8(dout,addr,din,wclk,wen);
    parameter LGDEPTH = 4;  // log of the size of the largest packet
    output [7:0] dout;
    input  [LGDEPTH-1:0] addr;
    input  [7:0] din;
    input  wclk;
    input  wen;


    reg      [7:0] ram [(LGDEPTH ** 2)-1:0];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule



