module decoder(
    input  [31:0] instr,        // Full 32-b instruction
    input  Br_Ok,               // Asserted when condition for branching passes
    output RegWrite,            // Asserted when value needs to be written to regfile
    output ALUSrc,              // Deasserted - input 2 to ALU comes from regfile, Asserted - input 2 comes from immediate value
    output [1:0] PCSrc,         // 2'b00 - PC = PC + 4, 2'b10 - PC replaced by immediate value (absolute addressing), 2'b01 - PC replaced by output of branch compute adder (relative addressing)
    output [1:0] ToReg,         // 2'b00 - value to write to regfile comes from output of ALU, 2'b01 - value comes from memory, 2'b10 - value comes from PC+4 adder, 2'b11 - value comes from branch compute adder
    output [31:0] rv2_imm,      // The sign extended immediate value (that would be sent to the MUX before input 2 of ALU, or for determining instruction address in branch statements)
    output [5:0] ALUop,         // Contains the custom opcode sent to ALU for choosing what operation it needs to do
    output [4:0] rs1,           // First operand
    output [4:0] rs2,           // Second operand
    output [4:0] rd             // Destination register, incase any value needs to be written into it
);

    // func7 (opcode) possiblities : LUI, AUIPC, JAL, JALR, OP, OP-IMM, STORE, LOAD, BRANCH
    parameter [6:0] LUI = 7'b0110111,
                    AUIPC = 7'b0010111,
                    JAL = 7'b1101111,
                    JALR = 7'b1100111,
                    BRANCH = 7'b1100011,
                    LOAD = 7'b0000011,
                    STORE = 7'b0100011,
                    OPIMM = 7'b0010011,
                    OP = 7'b0110011;

    // Sending a 6 bit custom opcode for ALU to handle different operations
    // For ALU instructions (OP and OPIMM), the opcode is derived from the bits that indicate some type or mode of operation (e.g, 5th bit of instruction is set for those not using immediate values)
    // Though ALU instructions explicitly use the ALU, all other instructions also need arithmetic or logical operations, though not as directly. So using the ALU for those operations as well
    // 6'b100011 : SUB, 6'b000001 : ADD, 6'b001011 : SLT, 6'b001111 : SLTU   ------> in custom opcode for ALU
    assign ALUop = (instr[6:0] == OP || instr[6:0] == OPIMM) ? {instr[30],instr[14:12],instr[5:4]} :   // handles OP and OPIMM instructions
                   (instr[6:0] == BRANCH && instr[14] == 0) ? 6'b100011 :                              // BRANCH instructions BEQ and BNE require subtraction of operands (SUB) to check for equality  
                   (instr[6:0] == BRANCH && instr[14] == instr[13]) ? 6'b001111 :                      // BRANCH instructions BLTU and BGEU require checking unisgned op1 < unsigned op2 (SLTU)
                   (instr[6:0] == BRANCH && instr[14] == 1) ? 6'b001011 : 6'b000001;                   // BRANCH instructions BLT and BGE require checking p1 < op2 (SLT)\
                   // All other instructions require adding immediate value to value in rs1, hence ADD

    // Assigning rs1, rs2, rd portions of the instructions asynchronously
    assign rs1 = (instr[6:0] == LUI) ? 5'b00000 : instr[19:15];                                       // We can treat LUI instruction as adding the immediate value to x0 (zero), so that we use the ALU effectively. For other cases, normal rs1 portion is assigned
    assign rs2 = instr[24:20];                                                                                      
    assign rd =  instr[11:7];                                                                           

    assign RegWrite = (instr[6:0] != BRANCH) && (instr[6:0] != STORE);                               // Except BRANCH and STORE instructions, other instructions require something to be written into registers

    assign ALUSrc = (instr[6:0] != BRANCH && instr[6:0] != OP);                                      // BRANCH and OP instructions alone need rv2 of ALU to come from r_rv2

    assign PCSrc = (instr[6:0] == JALR) ? 2'b10 :                                                    // JALR uses absolute addressing, other branching use relative addressing
                   (instr[6:0] == JAL || (instr[6:0] == BRANCH && Br_Ok)) ? 2'b01 : 2'b00;           // We update PCSrc for BRANCH instructions only if the condition turns true (i.e) Br_Ok is asserted

    assign ToReg = (instr[6:0] == LOAD) ? 2'b01 :                                                 // LOAD instruction requires value to be written into regfile to come from data memory
                      (instr[6:0] == JAL || instr[6:0] == JALR) ? 2'b10 :                            // JAL and JALR instruction requires value to come from PC+4 adder, as the next instruction address needs to be stored in rd before unconditionally branching
                      (instr[6:0] == AUIPC) ? 2'b11 : 2'b00;                                         // AUIPC requires value to come from branch compute adder which adds the immediate value to the value in PC

    assign rv2_imm = (instr[6:0] == LUI || instr[6:0] == AUIPC) ? { instr[31:12], {12{1'b0}} } :                                    // AUIPC and LUI alone require filling of 12 LSB bits to zeros, as they take immediate value to their MSB bits
                     (instr[6:0] == JAL) ? { {11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 } :            // Immediate for JAL needs to be filled with 0 in 0th bit to make it a multiple of 2, and it is sign extended
                     (instr[6:0] == BRANCH) ? { {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 } :           // Immediate for BRANCH needs to be filled with 0 in 0th bit to make it a multiple of 2, and it is sign extended
                     (instr[6:0] == STORE) ? { {20{instr[31]}}, instr[31:25], instr[11:7] } : { {20{instr[31]}}, instr[31:20] };    // Immediate value for any other instruction will be 12 bits in instr[31:20] that need to be sign extended
                    // Immediate value for OP type instructions won't be used at all, so it is included in other instructions

endmodule
