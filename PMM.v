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
	reg[63:0] REP_POS[0:255]; 		// REP_POS is an alias for SELFLOOP
	reg[63:0] MOVE[0:255];
	reg[63:0] Eps_BEG;
	reg[63:0] Eps_BLK;
	reg[63:0] Eps_END;
	reg[63:0] INIT;
	reg[63:0] ACCEPT;
	reg[63:0] STATE;
	reg[63:0] HIGH;
	reg[63:0] LOW;

	// temporary registers for implementing Extended NFA algorithm
	reg [63:0] NEW_STATE,TMP_STATE; 

	// reg ready_status,accepted_status;
	wire [1:0] Opcode;		// Opcode 2 bits decoded from the INP_CONTROL
	wire [13:0] Addr;		// Address 14 bits decoded from the INP_CONTROL
	wire Addr_Ok;			// HIGH if address is wthin the range 0-516 of the Memory
	reg mwe;				// Memory write enable : HIGH when we need to write INP_DATA into memory at Addr address
	reg swe;				// STATE write enable : HIGH when we need to update STATE

	integer i;

	initial begin       // cleaning memory the first time around
		for(i = 0;i<517;i=i+1) begin
			Memory[i] = 0;
		end
		// ready_status = 0;
		// accepted_status = 0;
		for(i=0;i<256;i=i+1) begin
			REP_POS[i] = 0;
			MOVE[i]    = 0;
		end
		Eps_BEG   = 0;
		Eps_BLK   = 0;
		Eps_END   = 0;
		INIT      = 0;
		ACCEPT    = 0;
		STATE     = 0;
		HIGH      = 0;
		LOW       = 0;
		TMP_STATE = 0;
		NEW_STATE = 0;
		READY_STATUS = 0;
		ACCEPTED_STATUS = 0;
	end

	// Decoding the Parameters
	always @(*) begin
		for(i = 0;i < 256;i=i+1) begin
			REP_POS[i] = Memory[i];
			MOVE[i]    = Memory[256+i];
		end
		Eps_BEG = Memory[512];
		Eps_BLK = Memory[513];
		Eps_END = Memory[514];
		INIT    = Memory[515];
		ACCEPT  = Memory[516];
	end

	// Breaking down the control signal into opcode and address
	assign Opcode = INP_CONTROL[15:14];
	assign Addr   = INP_CONTROL[13:0];

	// Finding if the Address is within the Memory range
	assign Addr_Ok = (Addr[13:3] < 517);

	always @(DATA_VALID or INP_CONTROL or INP_DATA) begin

		if(!DATA_VALID) begin
			READY_STATUS <= 0;  	// make READY_STATUS 0 on encountering a No operation
			ACCEPTED_STATUS <= 0;
			mwe <= 0;
			swe <= 0;
		end

		else begin
			case(Opcode)

				2'b00: begin						// No Operation Case
					READY_STATUS <= 0;  			// make READY_STATUS 0 on encountering a No operation
					ACCEPTED_STATUS <= 0;
					mwe <= 0;
					swe <= 0;
				end

				2'b01: begin                   		// Pre-Processing Case : write bit mask into Memory
					mwe <= 1;
					ACCEPTED_STATUS <= 0;
					swe <= 0;
				end

				2'b10: begin                   		// Simulation Case : Decode and implement Extended NFA algorithm

					mwe <= 0;
					swe <= 1;

					// Implementing Extended NFA algo
					TMP_STATE = ( ((STATE << 1) | INIT) & MOVE[INP_DATA[7:0]] ) | ( STATE & REP_POS[INP_DATA[7:0]] ); // The alpha transitions, LSB 8 bits of INP_DATA is the character
					HIGH  = TMP_STATE | Eps_END;
					LOW   = HIGH - Eps_BEG;
					NEW_STATE = (Eps_BLK & ((~ LOW) ^ HIGH)) | TMP_STATE;

					// Testing if the Pattern Matching was a success (i.e) the Accepted state is reached in the NFA
					if(NEW_STATE & ACCEPT)
						ACCEPTED_STATUS <= 1;		// Emit a match

					else
						ACCEPTED_STATUS <= 0;

				end

				2'b11: begin                     	// Reset Case : reset STATE to 0
					mwe <= 0;
					swe <= 0;
					STATE <= 0;	
					ACCEPTED_STATUS <= 0;					
				end

			endcase
		end

	end

	always @(posedge clk) begin
		if(DATA_VALID && !READY_STATUS) begin
			if(mwe && Addr_Ok) begin
				Memory[Addr[13:3]] = INP_DATA;  
				// Here I'm ignoring the bottom 3 bits since only the top 11 correspond to the Memory indices.
				// The address given is byte adddressable memory; the LSB 3 bits are not considered to prevent memory alignment problem
			end
			if(swe) begin
				STATE = NEW_STATE;
			end
			READY_STATUS = 0;
		end
	end


endmodule
