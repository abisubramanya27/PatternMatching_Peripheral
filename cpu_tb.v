`timescale 1ns/1ns 

// You may need to change the NCYCLES value till the program prints properly
// since we don't know how long the print functions will take
`define NCYCLES 10000

// This test bench will run for a fixed 1000 clock cycles and then dump out the memory
// Test cases are such that they should finish within this time
// If the CPU continues after this point, it should not result in changes in data
// Safe to assume that imem contains only 0 after the last instruction

// MACROS:
// A single parameter is passed into the code, 
// which is the path to the files imem.mem, dmem0-3.mem and expout.mem
// Test cases ensure the files are named appropriately
module cpu_tb ();
    
    reg  clk, reset;
    wire [31:0] iaddr, idata, daddr, drdata, dwdata;
    wire [31:0] daddr1, drdata1, dwdata1;
    wire [31:0] daddr2, drdata2, dwdata2;
    wire [3:0] dwe, dwe1, dwe2;
    integer i, s, fail, log_file, exp_file;
    reg [31:0] dtmp, exp_reg;

    // Instantiate the CPU
    cpu u1(
        .clk(clk),
        .reset(reset),
        .iaddr(iaddr),
        .idata(idata),
        .daddr(daddr),
        .drdata(drdata),
        .dwdata(dwdata),
        .dwe(dwe)
    );

    imem u2(
        .iaddr(iaddr),
        .idata(idata)
    );

    dmem u3(
        .clk(clk),
        .daddr(daddr1),
        .drdata(drdata1),
        .dwdata(dwdata1),
        .reset(reset),          // Addition to the existing dmem file - Added to make sure no data is written into memory when reset is high
        .dwe(dwe1)
    );

    outperiph u4( 
        .clk(clk),
        .reset(reset),          // Send reset 
        .daddr(daddr2),
        .drdata(drdata2),
        .dwdata(dwdata2),
        .dwe(dwe2)
    );

    biu u5(
        .clk(clk),
        .reset(reset),
        // Interface to CPU
        .daddr(daddr),
        .drdata(drdata),
        .dwdata(dwdata),
        .dwe(dwe),
        // Interface to DMEM
        .daddr1(daddr1),
        .drdata1(drdata1),
        .dwdata1(dwdata1),
        .dwe1(dwe1),
        // Interface to peripheral
        .daddr2(daddr2),
        .drdata2(drdata2),
        .dwdata2(dwdata2),
        .dwe2(dwe2)
    );

    // Set up clock
    always #5 clk=~clk;

    initial begin
	// Uncomment below to dump out VCD file for gtkwave
	// NOTE: This will NOT work on the jupyter terminal
	// $dumpfile("cpu_tb.vcd");
	// $dumpvars(0, "cpu_tb");
        $display("RUNNING TEST FROM ", `TESTDIR);
        clk = 1;
        reset = 1;   // This is active high reset
        #100         // At least 100 because Xilinx assumes 100ns reset in post-syn sim
        reset = 0;   // Reset removed - normal functioning resumes
        @(posedge clk);
        for (i=0; i<`NCYCLES; i=i+1) begin
            @(posedge clk);
        end
        
        $finish;
    end

endmodule
