module cpu (
    input clk,              // Clock signal - PC is updated at posedge of clock
    input reset,            // No memory or register must be written when reset is high, also it brings the PC back to the first instruction
    output [31:0] iaddr,    // address of the instruction to be read
    input [31:0] idata,     // full 32 bit instruction
    output [31:0] daddr,    // address in the memory
    input [31:0] drdata,    // data read from the memory
    output [31:0] dwdata,   // data to be written into the memory
    output [3:0] dwe        // bitmask for writing into the 4 banks of a memory
);
    // Declaring some outputs as reg so that they can written inside the always block
    reg [31:0] iaddr;
    reg [31:0] daddr, dwdata;
    reg [3:0]  dwe;

    // Intermediate registers and wires which link various modules and blocks
    reg [31:0] drdata_f;        // data read from data memory after proper shifting and sign extending
    wire [4:0] rs1, rs2, rd;    // rs1 - address of first operand in regfile, rs2 - address of second operand in regfile, rd - address of destination in regfile
    wire [31:0] rv1, rv2, r_rv2, rv2_imm, rvout, rwdata, PCplus4, Br_Adder;  
    // rv1 - value of 1st operand from regfile, r_rv2 contains the value of 2nd operand from regfile corresponding to rs2 address,
    // rv2_imm contains the immediate value which may be passed to ALU as it's second input instead of r_rv2, rvout - output value from ALU,
    // rwdata - contains the data to be written to regfile, PCplus4 - contains value in PC + 4, as the name suggests,
    // Br_Adder - output of branch compute adder which contains rv2_imm added to value in PC (used for relative branching)
    wire [5:0] ALUop;               // custom opcode for use in ALU

    // Control signals
    reg Br_Ok;                      // used to determine whether branching needs to take place or not for conditional branching                    
    wire RegWrite, ALUSrc;          // RegWrite - used to determine whether regfile has to be written or not, ALUSrc - used to determine the source for 2nd input for ALU
    wire [1:0] PCSrc, ToReg;        // PCSrc - used to determine source for the PC, ToReg - used to determine source for writing into the registers in regfile

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

    // Instantiate ALU
    alu32 u4(
        .op(ALUop),
        .rv1(rv1),
        .rv2(rv2),
        .rvout(rvout)
    );

    // Instantiate RegFIle
    regfile u5(
        .reset(reset),
        .clk(clk),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .we(RegWrite),
        .wdata(rwdata),
        .rv1(rv1),
        .rv2(r_rv2)
    );

    // Instantiate Decoder
    decoder u6(
        .instr(idata),
        .Br_Ok(Br_Ok),
        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .PCSrc(PCSrc),
        .ToReg(ToReg),
        .rv2_imm(rv2_imm),
        .ALUop(ALUop),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd)
    );


    // Passing the reset signal to memory and regfile so that they are not written when reset is high. Also starting the iaddr at zero to avoid any wrong instruction memory access
    // If reset turns from high to low before posedge, then during posedge the result of zero instruction gets written into memory or regfile, and the next instruciton starting at address 4 gets read
    // If reset turns form high to low after poseedge, then at posedge nothing is written into memory or regfile, but the values, operations and control signals corresponding to instruciton 0 are in place, and waits for the next posedge to make modifications in memory or regfile

    // The below block assigns proper instruction address at posedge of clock to iaddr to handle branching and resets
    always @(posedge clk) begin
        if (reset) begin
            iaddr <= 0;
        end else begin 
            case (PCSrc)                                        
                2'b10 : iaddr <= rvout;                         // iaddr takes the output value of adder which adds the values in rs1 with immediate value for absolute addressing              
                2'b01 : iaddr <= Br_Adder;                      // iaddr takes the output of branch compute adder for relative addressing     
                default : iaddr <= PCplus4;                     // iaddr takes the normal PC = PC + 4     
            endcase
        end
    end

    // The below statements form the adders used to generate instruction addresses possible to be assigned next depending on branching and normal flow
    assign PCplus4 = iaddr + 4;                                 // Output of the usual PC = PC + 4 
    assign Br_Adder = iaddr + rv2_imm;                          // Output of Branch compute adder which adds the immediate value to PC, used when relative addressing is needed
    
    // The below statements provide a MUX to value written into regfile and to 2nd input of ALU
    assign rv2 = (ALUSrc) ? rv2_imm : r_rv2;                    // rv2 is the input 2 to the ALU
    assign rwdata = (ToReg == 2'b01) ? drdata_f :               // drdata_f - value read from the memory, after proper shifting and masking written into regfile
                    (ToReg == 2'b10) ? PCplus4 :                // PCplus4 - value of PC+4 written into regfile (useful in storing the return address while unconditionally branching)
                    (ToReg == 2'b11) ? Br_Adder : rvout;        // Br_Adder - output of branch compute adder written into regfile in case of instructions like AUIPC, rvout - output of ALU written into regfile


    // The below block handles what is read from and written into memory and at what address, and whether conditional branching should occur 
    // Not using shifting (<< or >>) operators here to avoid using arithmetic operations separately for shifting, masking and sign extending load and store values
    always @(idata or rvout or drdata or r_rv2) begin                               // rvout contains the output of ALU
        case (idata[6:0])
            STORE : begin                                                           
                // STORE instructions require proper shifting and masking of values written into memory
                daddr <= rvout;                                                     // output of adder (immediate value added to value in rs1) contains the address in memory to be written into
                drdata_f <= drdata;                                                 // The data read from memory (whether intentional or not), doesn't require shifting and masking 
                Br_Ok <= 0;                                                         // No branching in STORE instruction

                // The bitmask for writing data into the banks of a memory address and the data to be written updated based on type of STORE instruction and the address alignement
                // r_rv2, the value corresponding to rs2 address in regfile is the source of data to be written into memory
                if(idata[14:12] == 3'b010 && rvout[1:0] == 2'b00) begin             // SW instruction with 4n address
                    dwe <= 4'b1111;
                    dwdata <= r_rv2;
                end
                else if(idata[14:12] == 3'b001 && rvout[1:0] == 2'b00) begin        // SH instruction with 4n address
                    dwe <= 4'b0011;
                    dwdata <= r_rv2;
                end
                else if(idata[14:12] == 3'b001 && rvout[1:0] == 2'b10) begin        // SH instruction with 4n+2 address
                    dwe <= 4'b1100;
                    dwdata <= { r_rv2[15:0],{16{1'b0}} };
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b00) begin        // SB instruction with 4n address
                    dwe <= 4'b0001;
                    dwdata <= r_rv2;
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b01) begin        // SB instruction with 4n+1 address
                    dwe <= 4'b0010;
                    dwdata <= { {16{1'b0}}, r_rv2[7:0], {8{1'b0}} };
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b10) begin        // SB instruction with 4n+2 address
                    dwe <= 4'b0100;
                    dwdata <= { {8{1'b0}}, r_rv2[7:0], {16{1'b0}} };
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b11) begin        // SB instruction with 4n+3 address
                    dwe <= 4'b1000;
                    dwdata <= { r_rv2[7:0], {24{1'b0}} };
                end
                else begin
                    dwe <= 4'b0000;
                    dwdata <= r_rv2;
                end
            end

            LOAD : begin                                                            
                // LOAD instructions require proper shifting and masking of values read from memory
                dwe <= 4'b0000;                                                     // All bits of bitmask used to write to memory low here since there should not be anything written
                daddr <= rvout;                                                     // output of adder (immediate value added to value in rs1) contains the address to read data from
                dwdata <= r_rv2;                                                    // Since the write enable for memory is off, no data will be written anyway. So assigning to default r_rv2
                Br_Ok <= 0;                                                         // No branching in LOAD instruction

                // The data read from memory has to be shifted and masked based on the type of LOAD instruction and address alignment
                if(idata[14:12] == 3'b001 && rvout[1:0] == 2'b00) begin             // LH instruction with 4n address
                    drdata_f <= { {16{drdata[15]}}, drdata[15:0] };
                end
                else if(idata[14:12] == 3'b001 && rvout[1:0] == 2'b10) begin        // LH instruction with 4n+2 address
                    drdata_f <= { {16{drdata[31]}}, drdata[31:16] }; 
                end
                else if(idata[14:12] == 3'b101 && rvout[1:0] == 2'b00) begin        // LHU instruction with 4n address
                    drdata_f <= { {16{1'b0}}, drdata[15:0] };
                end 
                else if(idata[14:12] == 3'b101 && rvout[1:0] == 2'b10) begin        // LHU instruction with 4n+2 address
                    drdata_f <= { {16{1'b0}}, drdata[31:16] }; 
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b00) begin        // LB instruction with 4n address
                    drdata_f <= { {24{drdata[7]}}, drdata[7:0] };
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b01) begin        // LB instruction with 4n+1 address
                    drdata_f <= { {24{drdata[15]}}, drdata[15:8] };
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b10) begin        // LB instruction with 4n+2 address
                    drdata_f <= { {24{drdata[23]}}, drdata[23:16] };
                end
                else if(idata[14:12] == 3'b000 && rvout[1:0] == 2'b11) begin        // LB instruction with 4n+3 address
                    drdata_f <= { {24{drdata[31]}}, drdata[31:24] };
                end
                else if(idata[14:12] == 3'b100 && rvout[1:0] == 2'b00) begin        // LBU instruction with 4n address
                    drdata_f <= { {24{1'b0}}, drdata[7:0] };
                end
                else if(idata[14:12] == 3'b100 && rvout[1:0] == 2'b01) begin        // LBU instruction with 4n+1 address
                    drdata_f <= { {24{1'b0}}, drdata[15:8] };
                end
                else if(idata[14:12] == 3'b100 && rvout[1:0] == 2'b10) begin        // LBU instruction with 4n+2 address
                    drdata_f <= { {24{1'b0}}, drdata[23:16] };
                end
                else if(idata[14:12] == 3'b100 && rvout[1:0] == 2'b11) begin        // LBU instruction with 4n+3 address
                    drdata_f <= { {24{1'b0}}, drdata[31:24] };
                end
                else begin                                                          // LW instruction with 4n address needs no special treatment, hence in else case
                    drdata_f <= drdata;
                end
            end

            BRANCH : begin
                // In BRANCH instruction assigning default values to the below registers, since there is nothing to do with memory here
                dwe <= 4'b0000;
                daddr <= {32{1'b0}};
                dwdata <= r_rv2;
                drdata_f <= drdata;

                // The below case determines whether condition for branching is satisfied
                case (idata[14:12])                                                 // func3 - 001 : BNE, 100 : BLT, 110 : BLTU , 000 : BEQ, 101 : BGE, 111 : BGEU
                    3'b001, 3'b100, 3'b110 : Br_Ok <= rvout != 0;                   // BNE does rv1 - rv2 ; BLT does $signed(rv1) < $signed(rv2) ;  BLTU does $unsigned(rv1) < $unsigned(rv2) --- In all cases result != 0 implies branching needs to happen
                    3'b000, 3'b101, 3'b111 : Br_Ok <= rvout == 0;                   // BEQ does rv1 - rv2 ; BGE does $signed(rv1) < $signed(rv2) ;  BGEU does $unsigned(rv1) < $unsigned(rv2) --- In all cases result == 0 implies branching needs to happen
                endcase
            end

            default : begin
                // Any other instruction has nothing to do with branching or memory, hence assigning default values
                dwe <= 4'b0000;
                daddr <= {32{1'b0}};
                dwdata <= r_rv2;
                drdata_f <= drdata;
                Br_Ok <= 0;
            end

        endcase
    end

endmodule