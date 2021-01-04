`define NO_MODULES 4
`define NO_BITS 2      // Number of bits needed to represent these number of modules

// 0x400000 - 0x400013 -> the memory map for Pattern matching peripheral

module PMP_interface (
    input clk,
    input [31:0] daddr,
    input [31:0] dwdata,
    input [3:0] dwe,
    input reset,
    output [31:0] drdata 
);
    
    reg [7:0] data_buffer[0:7];
    reg [0:`NO_MODULES-1][63:0] pmp_data;
    reg [0:`NO_MODULES-1][15:0] pmp_control;
    reg [31:0] data_ready;
    reg [31:0] data_accepted;
    reg [31:0] pattern_accepted;
    wire [31:0] pmp_data_acc;
    wire [31:0] pmp_pattern_acc;
    
    PMP u7(
        .data(pmp_data),                     // Output
        .control(pmp_control),               // Output
        .data_ready(data_ready),             // Output
        .data_accepted(pmp_data_acc),        // Input
        .pattern_accepted(pmp_pattern_acc)   // Input
    );

    wire [29:0] a;
    assign a = daddr[31:2];
    
    integer i;
    initial begin  
        for (i=0; i<8; i=i+1) begin
            data_buffer[i] = 0;
        end
        for (i=0; i<`NO_MODULES; i=i+1) begin
            pmp_data[i] = 0;
            pmp_control[i] = 0;
        end
        data_ready = 0;
        data_accepted = 0;
        pattern_accepted = 0;
    end

    // Reading data only when dwe is low and the correct target address is specified
    assign drdata = (a == {28'h0040000, 2'b11} && dwe == 0) ? data_accepted :
                    (a == {28'h0040001, 2'b00} && dwe == 0) ? pattern_accepted : 0;
    
    always @(posedge clk) begin
        // Writing to DATA_BUFFER's LSB and MSB 32 bits
        if (a == {28'h0040000, 2'b00} || a == {28'h0040000, 2'b01}) begin
            if (!reset && dwe[3]) data_buffer[{a[0], 2'd3}] <= dwdata[31:24];
            if (!reset && dwe[2]) data_buffer[{a[0], 2'd2}] <= dwdata[23:16];
            if (!reset && dwe[1]) data_buffer[{a[0], 2'd1}] <= dwdata[15: 8];
            if (!reset && dwe[0]) data_buffer[{a[0], 2'd0}] <= dwdata[ 7: 0];
        end
        // Sending data and control values to target module (Mode 0)
        else if (a == {28'h0040000, 2'b10} && dwe[3:0] != 0 && dwdata[31] == 1'b0) begin 
            pmp_control[dwdata[`NO_BITS:0]] <= dwdata[30:15];
            pmp_data[dwdata[`NO_BITS:0]] <= {data_buffer[7], data_buffer[6], data_buffer[5], data_buffer[4], data_buffer[3], data_buffer[2], data_buffer[1], data_buffer[0]};
            // Writing DATA_READY from PMM_CONTROL; 0 will be written in case of No Operation instruction, and 1 otherwise
            data_ready[dwdata[`NO_BITS:0]] <= (dwdata[30:29] == 2'b00) ? 0 : 1;
        end
        // Sending data and control values to all modules (Mode 1)
        else if (a == {28'h0040000, 2'b10} && dwe[3:0] != 0 && dwdata[31] == 1'b1) begin
            pmp_control[0] <= dwdata[30:15];
            pmp_control[1] <= dwdata[30:15];
            pmp_control[2] <= dwdata[30:15];
            pmp_control[3] <= dwdata[30:15];            
            pmp_data[0] <= {data_buffer[7], data_buffer[6], data_buffer[5], data_buffer[4], data_buffer[3], data_buffer[2], data_buffer[1], data_buffer[0]};
            pmp_data[1] <= {data_buffer[7], data_buffer[6], data_buffer[5], data_buffer[4], data_buffer[3], data_buffer[2], data_buffer[1], data_buffer[0]};
            pmp_data[2] <= {data_buffer[7], data_buffer[6], data_buffer[5], data_buffer[4], data_buffer[3], data_buffer[2], data_buffer[1], data_buffer[0]};
            pmp_data[3] <= {data_buffer[7], data_buffer[6], data_buffer[5], data_buffer[4], data_buffer[3], data_buffer[2], data_buffer[1], data_buffer[0]};
            // Writing DATA_READY from PMM_CONTROL; 0 will be written in case of No Operation instruction, and 1 otherwise
            data_ready[3:0] <= (dwdata[30:29] == 2'b00) ? 4'b0000 : 4'b1111;
        end   

        // Assigning DATA_ACCEPTED and PATTERN_ACCEPTED from Pattern matching peripheral
        data_accepted <= pmp_data_acc;
        pattern_accepted <= pmp_pattern_acc;
    end

endmodule 