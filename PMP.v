`timescale 1ns/1ps
`define NO_MODULES 4

module PMP(
    input [0:`NO_MODULES-1][63:0] data,
    input [0:`NO_MODULES-1][15:0] control,
    input [31:0] data_ready,
    output [31:0] data_accepted,
    output [31:0] pattern_accepted   
);
    
    reg clk;
    reg [63:0] pmp_data[0:`NO_MODULES-1];
    reg [15:0] pmp_control[0:`NO_MODULES-1];
    reg [31:0] pmp_data_ready;

    always #10 clk = ~clk;          // 50 MHz clock

    integer i;
    initial begin
        clk = 1;
        pmp_data_ready = 0;
        for (i=0; i<`NO_MODULES; i=i+1) begin
            pmp_data[i] = 0;
            pmp_control[i] = 0;
        end
    end
    
    generate
        genvar j;
        for (j=0; j<`NO_MODULES; j=j+1) begin : pmm
            PMM m (
                .clk(clk),
                .INP_DATA(pmp_data[j]),
                .INP_CONTROL(pmp_control[j]),
                .DATA_VALID(pmp_data_ready[j]),
                .READY_STATUS(data_accepted[j]),
                .ACCEPTED_STATUS(pattern_accepted[j])
            ); 
        end
        for (j=`NO_MODULES; j<32; j=j+1) begin : status_bits
            assign data_accepted[j] = 0;
            assign pattern_accepted[j] = 0;
        end
    endgenerate   
    
    always @(posedge clk) begin
        for(i=0; i <`NO_MODULES; i=i+1) begin
           pmp_data[i] <= data[i];
           pmp_control[i] <= control[i]; 
        end
        pmp_data_ready <= data_ready;              
    end


endmodule
