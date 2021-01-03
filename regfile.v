module regfile(
    input [4:0] rs1,     // address of first operand to read - 5 bits, since there are 32 registers
    input [4:0] rs2,     // address of second operand
    input [4:0] rd,      // address of value to write
    input we,            // should write update occur
    input [31:0] wdata,  // value to be written
    output [31:0] rv1,   // First read value
    output [31:0] rv2,   // Second read value
    input clk,           // Clock signal - all memory write operations happen at clock posedge
    input reset          // only if reset = 0 we write to regfile
);
    // Desired function
    // rv1, rv2 are combinational outputs - they will update whenever rs1, rs2 change
    // On clock posedge, if we=1, regfile entry for rd will be updated provided rd != 0 and reset is low

    reg [31:0] reg_arr [0:31]; // 32 registers each with 32 bits
    integer i; // to be used in for loop
    initial begin
        for(i = 0;i < 32;i = i+1) begin
            reg_arr[i] = {32{1'b0}}; // All 32 registers initialised to zero
        end
    end

    // Combinational circuit for reading values
    assign rv1 = reg_arr[rs1];
    assign rv2 = reg_arr[rs2];

    // Sequential circuit for writing value into register
    always @(posedge clk) begin
        if(!reset && we && rd) // register 0 hardwired to zero, so won't change
            reg_arr[rd] <= wdata;
    end

endmodule