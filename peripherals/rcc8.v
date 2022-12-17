//////////////////////////////////////////////////////////////////////////
//
//  File: rcc8.v;   Resistor Capacitor analog to digital Converter
//
//      This peripheral interfaces a Pololu quad QTR-RC sensor or to 
//  other RC based sensors.  The idea is that a capacitor is discharged
//  by a pulse from the FPGA.  A timer is started for each input.  The
//  timer is stopped when the capacitor charge passes the 0->1 logic
//  threshold of the FPGA pin.  A lower timer count indicates a faster
//  charge and so a lower resistance.
//
//  The time base is user selectable from one of four clock rates.
//  The timer counts are all 8 bits.  The start pulse can be either
//  a 10 us pulse to Vcc or a pulse to ground.
//
//  The sampling period is controlled by a 4 bit register and can be
//  set between 0 and 150ms.  A value of zero is the default and turns
//  off the sensor polling.  
//
//  Registers
//  0-7:   Sensor values.  8 bits
//  8  :   configuration:
//            bits 3:0 are the sampling period
//            bits 5:4 are the clock source selector
//            bit  6   is the polarity of the initial pulse
//
/////////////////////////////////////////////////////////////////////////

// This code implements a simple state machine.  RCCIDLE if done counting 
// and waiting for the start of a poll.  CHARGING if discharging the
// capacitor, and SENSING while reading the inputs and counting
`define RCCIDLE    2'h0
`define CHARGING   2'h1
`define SENSING    2'h2

module rcc8(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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
    inout  [7:0] pins;       // RCC-RC inputs

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
 
    // Counter state and signals
    reg    data_avail;       // Flag to say data is ready to send
    reg    [3:0] polltime;   // Poll interval in units of 10ms.  0==off
    reg    [3:0] pollcount;  // Counter from 0 to polltime.
    reg    [1:0] clksrc;     // 00=n100, 01=u1, 10=u10, 11=u100
    reg    polarity;         // ==1 to charge cap to 1 
    reg    [7:0] rccval;     // sampled pin values
    reg    [1:0] state;      // One of idle, charging, or sensing
    reg    [7:0] count;      // counts while cap is charging
    wire   countclk;         // clock to drive counters

    // Counts are stored in RAM with one RAM location per input pin
    wire   [7:0] countout;   // RAM output lines
    wire   [7:0] countin;    // RAM input lines
    wire   [2:0] raddr;      // RAM address lines
    wire   countwen;         // RAM write enable
    ram8x8rcc rccram(countout,raddr,countin,CLK_I,countwen);
    reg    [2:0] rccsel;     // Select which input pin to examine

    // Generate the clock source for the timers
    assign countclk = (clksrc == 2'h0) ? clocks[`U1CLK] :
                      (clksrc == 2'h1) ? clocks[`U10CLK] :
                      (clksrc == 2'h2) ? clocks[`U100CLK] :
                      (clksrc == 2'h3) ? clocks[`M1CLK] : 0;
    assign m10clk = clocks[`M10CLK];
    assign u10clk = clocks[`U10CLK];


    initial
    begin
        state = `RCCIDLE;
        data_avail = 0;
        polltime = 0;
        pollcount = 1;
        clksrc = 0;
        count = 0;
        rccsel = 0;
        rccval = 0;
    end

    always @(posedge CLK_I)
    begin
        // Handle write requests from the host
        if (TGA_I & myaddr & WE_I & (ADR_I[3:0] == 4'h8))       // latch data on a write
        begin
            polltime <= DAT_I[3:0];             // how often to poll pins
            clksrc   <= DAT_I[5:4];             // which clock to drive counters
            polarity <= DAT_I[6];               // ==1 to charge cap to 1 
        end
        // Any read from the host clears the data available flag.
        else if (TGA_I & myaddr & ~WE_I) // if a read from the host
        begin
            // Clear data_available if we are sending up to the host
            data_avail <= 0;
        end


        // Update pollcount and start charging the RCC cap at timeout
        if (m10clk && (state == `RCCIDLE))
        begin
            if (polltime != 0)
            begin
                if (pollcount == polltime)
                begin
                    state <= `CHARGING;     // Charge the RCC cap
                    pollcount <= 1;         // restart polling counter
                end
                else
                    pollcount <= pollcount + 4'h1;
            end
        end
        else if (u10clk && (state == `CHARGING))
        begin
            // We need to charge the cap for 1 us but do so for one 10us period
            state <= `SENSING;              // Wait for cap charge (or discharge)
            count <= 8'h00;                 // Start timer/counter
        end
        else if (countclk && (state == `SENSING))
        begin
            // Waiting for caps to charge or discharge
            if (count == 8'hff)
            begin
                data_avail <= 1;            // set flag to send data to host
                state <= `RCCIDLE;
            end
            else
                count <= count + 1;
        end

        // Every clock cycle we look at the next input pin
        else if (state == `SENSING)
        begin
            rccsel <= rccsel + 3'h1;
            rccval <= pins;
        end
    end

    assign pins[0] = (state == `CHARGING) ? polarity : 1'bz ;
    assign pins[1] = (state == `CHARGING) ? polarity : 1'bz ;
    assign pins[2] = (state == `CHARGING) ? polarity : 1'bz ;
    assign pins[3] = (state == `CHARGING) ? polarity : 1'bz ;
    assign pins[4] = (state == `CHARGING) ? polarity : 1'bz ;
    assign pins[5] = (state == `CHARGING) ? polarity : 1'bz ;
    assign pins[6] = (state == `CHARGING) ? polarity : 1'bz ;
    assign pins[7] = (state == `CHARGING) ? polarity : 1'bz ;

    assign raddr = (TGA_I & myaddr) ? ADR_I[2:0] : rccsel ;
    assign countin = count;                 // RAM input is always the count
    // copy count to RAM if sensing and the input pin is still at polarity
    assign countwen = (state == `SENSING) && (
                       ((rccsel == 0) && (rccval[0] == polarity)) ||
                       ((rccsel == 1) && (rccval[1] == polarity)) ||
                       ((rccsel == 2) && (rccval[2] == polarity)) ||
                       ((rccsel == 3) && (rccval[3] == polarity)) ||
                       ((rccsel == 4) && (rccval[4] == polarity)) ||
                       ((rccsel == 5) && (rccval[5] == polarity)) ||
                       ((rccsel == 6) && (rccval[6] == polarity)) ||
                       ((rccsel == 7) && (rccval[7] == polarity)));


    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    // send 1 byte per input pin
                    (~TGA_I && data_avail) ? 8'h08 :       // autosend eight bytes
                    (TGA_I & (ADR_I[3] == 0)) ? countout : // sent count from RAM
                    8'h00 ;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule

module ram8x8rcc(dout,addr,din,wclk,wen);
    output   [7:0] dout;
    input    [2:0] addr;
    input    [7:0] din;
    input    wclk;
    input    wen;

    reg      [7:0] ram [7:0];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule




