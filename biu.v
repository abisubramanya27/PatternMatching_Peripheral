`timescale 1ns/1ps
// Bus interface unit: assumes two branches of the bus -
// 1. connect to dmem
// 2. connect to a single peripheral
// The BIU needs to know the addresses at which DMEM and peripheral are
// connected, so it can do the required multiplexing. 
module biu (
    input clk,
    input reset,

    // Signals going to/from cpu
    input [31:0] daddr,
    input [31:0] dwdata,
    input [3:0] dwe,
    output [31:0] drdata,

    // Signals going to/from dmem
    output [31:0] daddr1,
    output [31:0] dwdata1,
    output [3:0]  dwe1,
    input  [31:0] drdata1,

    // Signals going to/from peripheral
    output [31:0] daddr2,
    output [31:0] dwdata2,
    output [3:0]  dwe2,
    input  [31:0] drdata2
);

    // DMEM memory map is from 0-16383 (i.e) 0x0 to 0x3FFF - in that range drdata to cpu will come from dmem
    // Output peripheral memory map is from 0x34560 to 0x34567

    // For address ranges other than those intennded for dmem and read memory map of output peripheral, data read is set as 0,
    // since no other peripheral needs to be memory mapped by BIU in this version
    assign drdata = (daddr[31:14] == {16'h0000,2'b00}) ? drdata1 : 
                    (daddr[31:2] == {28'h0003456,2'b01}) ? drdata2 : 0;

    // Data to dmem
    assign daddr1 = daddr;          // address is handled inside the dmem by removing 2 LSB, so doing nothing here
    assign dwdata1 = dwdata;        // the data to be written is sent as such to both dmem and peripheral because anyway it will be written only if enable is high
    assign dwe1 = (daddr[31:14] == {16'h0000,2'b00}) ? dwe : 0;              // enable is set only if address is intended for dmem

    // Data to Output peripheral
    assign daddr2 = daddr;          // address is handled inside the peripheral by taking only 3 LSB, so doing nothing here
    assign dwdata2 = dwdata;        // the data to be written is sent as such to both dmem and peripheral because anyway it will be written only if enable is high
    assign dwe2 = (daddr[31:2] == {28'h0003456,2'b00}) ? dwe : 0;             // enable is set only if address is intended for output peripheral's display locations

endmodule