`timescale 1ns/1ps

module imem (
    input [31:0] iaddr,     // address of the instruction to be read
    output [31:0] idata     // instruction data
);
    // Ignores LSB 2 bits, so will not generate alignment exception
    reg [31:0] mem[0:8192]; // Define a 8KB locations memory (32KB total bytes)
    initial begin $readmemh({`TESTDIR,"/idata.mem"},mem); end

    assign idata = mem[iaddr[31:2]];
endmodule