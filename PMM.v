// PMM MODULE

module PMM(
	input clk ,                    // Clock from outer peripheral
	input [63:0] INP_DATA,         // 64 bit input data
	input [15:0] INP_CONTROL,      // 16 bit input control (opcode -> 2 bits + address -> 14 bits)
	input DATA_VALID,    		   // alias for data_ready flag
	output reg READY_STATUS,  	   // HIGH if data accepted for handshaking -> alias for data_accepted flag
	output reg ACCEPTED_STATUS	   // HIGH if pattern matched -> alias for pattern_accepted flag
);


	// PMM Block RAMs : 64 bit registers
	reg [63:0] Memory_REPPOS[0:256];
	reg [63:0] Memory_MOVE[0:256];
	reg [63:0] Eps_BEG;
	reg [63:0] Eps_BLK;
	reg [63:0] Eps_END;
	reg [63:0] INIT;
	reg [63:0] ACCEPT;

	// Registers and wires for Simulation NFA
	wire [63:0] REPPOS; 	// REP_POS is an alias for SELFLOOP
	wire [63:0] MOVE;

	reg [63:0] STATE;
	reg [63:0] HIGH;
	reg [63:0] LOW;

	// temporary registers for implementing Extended NFA algorithm
	reg [63:0] NEW_STATE,TMP_STATE; 

	// reg ready_status,accepted_status;
	wire [1:0] Opcode;		// Opcode 2 bits decoded from the INP_CONTROL
	wire [13:0] Addr;		// Address 14 bits decoded from the INP_CONTROL
	// The following wires check if the address is targetted towards those set of registers
	wire Addr_REPPOS;
	wire Addr_MOVE;
	wire Addr_EpsBEG;
	wire Addr_EpsBLK;
	wire Addr_EpsEND;
	wire Addr_INIT;
	wire Addr_ACCEPT;
	wire pattern_accepted;	// HIGH if (NEW_STATE & ACCEPT) != 0

	integer i;

	initial begin       // cleaning memory the first time around
		for(i = 0;i<256;i=i+1) begin
			Memory_REPPOS[i] = 0;
			Memory_MOVE[i] = 0;
		end
		STATE     = 0;
		HIGH      = 0;
		LOW       = 0;
		TMP_STATE = 0;
		NEW_STATE = 0;
		READY_STATUS = 0;
		ACCEPTED_STATUS = 0;
		Eps_BEG = 0;
		Eps_BLK = 0;
		Eps_END = 0;
		INIT = 0;
		ACCEPT = 0;
	end

	// Breaking down the control signal into opcode and address
	assign Opcode = INP_CONTROL[15:14];
	assign Addr   = INP_CONTROL[13:0];

	// Finding the target set of registers to store into memory
	// Here I'm ignoring the bottom 3 bits since only the top 11 correspond to the Memory indices.
	// The address given is byte adddressable memory; the LSB 3 bits are not considered to prevent memory alignment problem
	assign Addr_REPPOS = (Addr[13:11] == 3'b000);
	assign Addr_MOVE = (Addr[13:11] == 3'b001);
	assign Addr_EpsBEG = (Addr[13:3] == {8'h40,3'b000});
	assign Addr_EpsBLK = (Addr[13:3] == {8'h40,3'b001});
	assign Addr_EpsEND = (Addr[13:3] == {8'h40,3'b010});
	assign Addr_INIT = (Addr[13:3] == {8'h40,3'b011});
	assign Addr_ACCEPT = (Addr[13:3] == {8'h40,3'b100});

	// Deocding the parameters - Taking the registers needed currently for simulating NFA alone
	assign REPPOS = Memory_REPPOS[INP_DATA[7:0]];				// LSB 8 bits of INP_DATA is the character
	assign MOVE = Memory_MOVE[INP_DATA[7:0]];					// LSB 8 bits of INP_DATA is the character

	always @(*) begin

		// Implementing Extended NFA algo
		TMP_STATE = ( ((STATE << 1) | INIT) & MOVE ) | ( STATE & REPPOS ); // The alpha transitions
		HIGH  = TMP_STATE | Eps_END;
		LOW   = HIGH - Eps_BEG;
		NEW_STATE = (Eps_BLK & ((~ LOW) ^ HIGH)) | TMP_STATE;

	end

	// Testing if the Pattern Matching was a success (i.e) the Accepted state is reached in the NFA
	assign pattern_accepted = ((NEW_STATE & ACCEPT) != 0);


	always @(posedge clk) begin
		if(DATA_VALID && !READY_STATUS) begin
			if(Opcode == 2'b01) begin		// Pre-Processing Case : write bit mask into Memory
				if(Addr_REPPOS) Memory_REPPOS[Addr[10:3]] = INP_DATA;
				if(Addr_MOVE)  Memory_MOVE[Addr[10:3]] = INP_DATA;
				if(Addr_EpsBEG) Eps_BEG = INP_DATA;
				if(Addr_EpsBLK) Eps_BLK = INP_DATA;
				if(Addr_EpsEND) Eps_END = INP_DATA;
				if(Addr_INIT) INIT = INP_DATA;
				if(Addr_ACCEPT) ACCEPT = INP_DATA;
			end
			else if(Opcode == 2'b10) begin				// Simulation Case : Decode and implement Extended NFA algorithm
				STATE = NEW_STATE;
				ACCEPTED_STATUS = pattern_accepted;
			end
			else if(Opcode == 2'b11) STATE = 0;			// Reset Case : reset STATE to 0
			READY_STATUS = 1;
		end
		else if(!DATA_VALID) begin
			READY_STATUS = 0;
		end
	end


endmodule
