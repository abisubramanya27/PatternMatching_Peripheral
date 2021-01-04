// PMM MODULE

module PMM(
	input clk ,                    // Clock from outer peripheral
	input [63:0] INP_DATA,         // 64 bit input data
	input [15:0] INP_CONTROL,      // 16 bit input control (opcode -> 2 bits + address -> 14 bits)
	input DATA_VALID,    		   // alias for data_ready flag
	output reg READY_STATUS,  	   // HIGH if data accepted for handshaking -> alias for data_accepted flag
	output reg ACCEPTED_STATUS	   // HIGH if pattern matched -> alias for pattern_accepted flag
);


	// PMM Block RAM 517 x 64 bit registers
	reg[63:0] Memory[0:516];

	// Registers and wires for Simulation NFA
	wire[63:0] REP_POS; 	// REP_POS is an alias for SELFLOOP
	wire[63:0] MOVE;
	wire[63:0] Eps_BEG;
	wire[63:0] Eps_BLK;
	wire[63:0] Eps_END;
	wire[63:0] INIT;
	wire[63:0] ACCEPT;

	reg[63:0] STATE;
	reg[63:0] HIGH;
	reg[63:0] LOW;

	// temporary registers for implementing Extended NFA algorithm
	reg [63:0] NEW_STATE,TMP_STATE; 

	// reg ready_status,accepted_status;
	wire [1:0] Opcode;		// Opcode 2 bits decoded from the INP_CONTROL
	wire [13:0] Addr;		// Address 14 bits decoded from the INP_CONTROL
	wire Addr_Ok;			// HIGH if address is wthin the range 0-516 of the Memory
	wire pattern_accepted;	// HIGH if (NEW_STATE & ACCEPT) != 0

	integer i;

	initial begin       // cleaning memory the first time around
		for(i = 0;i<517;i=i+1) begin
			Memory[i] = 0;
		end
		STATE     = 0;
		HIGH      = 0;
		LOW       = 0;
		TMP_STATE = 0;
		NEW_STATE = 0;
		READY_STATUS = 0;
		ACCEPTED_STATUS = 0;
	end

	// Breaking down the control signal into opcode and address
	assign Opcode = INP_CONTROL[15:14];
	assign Addr   = INP_CONTROL[13:0];

	// Finding if the Address is within the Memory range
	assign Addr_Ok = (Addr[13:3] < 517);

	// Deocding the parameters - Taking the registers needed currently for simulating NFA alone
	assign REP_POS = Memory[INP_DATA[7:0]];				// LSB 8 bits of INP_DATA is the character
	assign MOVE = Memory[256 + INP_DATA[7:0]];			// LSB 8 bits of INP_DATA is the character
	assign Eps_BEG = Memory[512];
	assign Eps_BLK = Memory[513];
	assign Eps_END = Memory[514];
	assign INIT = Memory[515];
	assign ACCEPT = Memory[516];

	always @(*) begin

		// Implementing Extended NFA algo
		TMP_STATE = ( ((STATE << 1) | INIT) & MOVE[INP_DATA[7:0]] ) | ( STATE & REP_POS[INP_DATA[7:0]] ); // The alpha transitions
		HIGH  = TMP_STATE | Eps_END;
		LOW   = HIGH - Eps_BEG;
		NEW_STATE = (Eps_BLK & ((~ LOW) ^ HIGH)) | TMP_STATE;

	end

	// Testing if the Pattern Matching was a success (i.e) the Accepted state is reached in the NFA
	assign pattern_accepted = ((NEW_STATE & ACCEPT) != 0);


	always @(posedge clk) begin
		if(DATA_VALID && !READY_STATUS) begin
			if(Opcode == 2'b01 && Addr_Ok) begin		// Pre-Processing Case : write bit mask into Memory
				Memory[Addr[13:3]] = INP_DATA;  
				// Here I'm ignoring the bottom 3 bits since only the top 11 correspond to the Memory indices.
				// The address given is byte adddressable memory; the LSB 3 bits are not considered to prevent memory alignment problem
			end
			else if(Opcode == 2'b10) begin				// Simulation Case : Decode and implement Extended NFA algorithm
				STATE = NEW_STATE;
				ACCEPTED_STATUS = pattern_accepted;
			end
			else if(Opcode == 2'b11) STATE = 0;			// Reset Case : reset STATE to 0
			READY_STATUS = 0;
		end
		else if(!DATA_VALID) begin
			READY_STATUS = 0;
		end
	end


endmodule
