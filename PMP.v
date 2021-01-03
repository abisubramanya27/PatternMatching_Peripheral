`timescale 1ns/1ps

module PMP(
    input [0:3][63:0] data,
    input [0:3][15:0] control,
    input [31:0] data_ready,
    output [31:0] data_accepted,
    output [31:0] pattern_accepted   
);
    
    reg clk;
    reg [63:0] pmp_data[0:3];
    reg [15:0] pmp_control[0:3];
    reg [31:0] pmp_data_ready;

    always #50 clk = ~clk;          // 10 MHz clock

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
        for (j = 1;j < 4;j=j+1) begin : pmm
            PMM m (
                .clk(clk),
                .INP_DATA(pmp_data[j]),
                .INP_CONTROL(pmp_control[j]),
                .DATA_VALID(pmp_data_ready[j]),
                .READY_STATUS(data_accepted[j]),
                .ACCEPTED_STATUS(pattern_accepted[j])
            ); 
        end
    endgenerate

    // PMM m1(   
    //     .clk(clk),
    //     .INP_DATA(pmp_data[0]),
    //     .INP_CONTROL(pmp_control[0]),
    //     .DATA_VALID(pmp_data_ready[0]),
    //     .READY_STATUS(data_accepted[0]),
    //     .ACCEPTED_STATUS(pattern_accepted[0])
    // );
     
    // PMM m2(  
    //     .clk(clk), 
    //     .INP_DATA(pmp_data[1]),
    //     .INP_CONTROL(pmp_control[1]),
    //     .DATA_VALID(pmp_data_ready[1]),
    //     .READY_STATUS(data_accepted[1]),
    //     .ACCEPTED_STATUS(pattern_accepted[1])
    // );
    
    // PMM m3(   
    //     .clk(clk),
    //     .INP_DATA(pmp_data[2]),
    //     .INP_CONTROL(pmp_control[2]),
    //     .DATA_VALID(pmp_data_ready[2]),
    //     .READY_STATUS(data_accepted[2]),
    //     .ACCEPTED_STATUS(pattern_accepted[2])
    // );
    
    // PMM m4(   
    //     .clk(clk),
    //     .INP_DATA(pmp_data[3]),
    //     .INP_CONTROL(pmp_control[3]),
    //     .DATA_VALID(pmp_data_ready[3]),
    //     .READY_STATUS(data_accepted[3]),
    //     .ACCEPTED_STATUS(pattern_accepted[3])
    // );    
    
    always @(posedge clk) begin
        for(i = 0;i < 4;i=i+1) begin
           pmp_data[i] <= data[i];
           pmp_control[i] <= control[i]; 
        end
        pmp_data_ready <= data_ready;              
    end


endmodule
