`timescale 1ns/1ps
`define OUTFILE "output.txt"

// 0x34560 - 0x34567 -> the memory map for Output Peripheral
// 0x34560 -> base address for writing (offset of 0x00)
// 0x34564 -> base address for read status (offset of 0x04)

module outperiph (
    input clk,
    input reset,
    input [31:0] daddr,
    input [31:0] dwdata,
    input [3:0] dwe,
    output [31:0] drdata
);
    
    // 32 bit counter for storing read status (no of values displayed) from system startup
    reg [31:0] memstatus;

    // Memory read happens asynchronously as in DMEM
    assign drdata = (daddr[2] == 1) ? memstatus : 0;    // status is read on the 0x04 offset to base address alone

    integer file_out;                                   // file handler to write output data provided
    
    // Output write happens at posedge of clock (synchronously)
    always @(posedge clk) begin
        if(reset) begin
            memstatus <= 0;                       // Counter is reset to 0, when system (instructions) is also reset
            file_out = $fopen(`OUTFILE,"w");      // Opening the OUTFILE in write mode to clear it's contents when reset is high
            $fclose(file_out);
        end
        // Output display at posedge of clock if reset is low and dwe is enabled
        // dwe and daddr for writing output compatibility is checked by BIU itsefl which makes the enable low in case of mismatch with memory map
        else if(dwe != 4'b0000) begin
            memstatus <= memstatus + 1;                 // Incrementing the counter by 1 as 1 Byte character is written/displayed
            file_out = $fopen(`OUTFILE,"a");            // Opening the OUTIFLE file in append mode so that the previous output displayed is not cleared without a reset
            $fwrite(file_out,"%c",dwdata[7:0]);         // Writing the character corresponding to ASCII value in LSB 8 bits to output file
            $fclose(file_out);                          // Closing the output file
        end
    end

endmodule