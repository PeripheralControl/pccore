`timescale 1ns/1ns

module dpram_tb;
    // direction is relative to the DUT
    reg    clk;        // system clock
    reg    we;         // write strobe
    reg    [5:0] wa;   // write address
    reg    [7:0] wd;   // write data
    reg    [4:0] ra;   // read address
    wire   [15:0]rd;   // read data

    // Add the device under test
    dpram dpram_dut(clk,we,wa,wd,ra,rd);

    // generate the clock(s)
    initial  clk = 0;
    always   #25 clk = ~clk;

    initial
    begin
        $dumpfile ("dpram_tb.xt2");
        $dumpvars (0, dpram_tb);

        #50   we = 0; wa = 0 ; wd = 5;
        #50   we = 1;
        #50   we = 0; wa = 1 ; wd = 6;
        #50   we = 1;
        #50   we = 0; wa = 2 ; wd = 7;
        #50   we = 1;

        #50   ra = 0;
        #50 $display("rd is %x", rd);
        #50   ra = 1;
        #50 $display("rd is %x", rd);
        #50   ra = 2;
        #50 $display("rd is %x", rd);

        #500  // some time later ...
        $finish;
    end
endmodule


//
// Dual-Port RAM with synchronous Read
//
module
dpram(clk,we,wa,wd,ra,rd);
    input    clk;                // system clock
    input    we;                 // write strobe
    input    [5:0] wa;           // write address
    input    [7:0] wd;           // write data
    input    [4:0] ra;           // read address
    output   [15:0] rd;           // read data

    reg      [15:0] rdreg;
    reg      [7:0] ram [63:0];

    always@(posedge clk)
    begin
        if (we)
            ram[wa] <= wd;
        rdreg[7:0] <= ram[(ra << 1) + 0];
        rdreg[15:8] <= ram[(ra << 1) + 1];
    end

    assign rd = rdreg;

endmodule

