# PMM MODULE

module PMM(
input clk ,                    #Clock from outer peripheral
input reg[63:0] INP_DATA,      #64 bit input bitmask
input reg[15:0] INP_CONTROL,   #16 bit input control(opcode + address)
input  DATA_VALID,    		   #data_ready flag
output READY_STATUS,  		   #HIGH if data accepted for handshaking
output ACCEPTED_STATUS		   #HIGH if pattern matched
);


	#PMM Block RAM 517 x 64 bit registers
	reg[63:0] Memory[0:516];

	#Registers and wires for Simulation
	wire[63:0] REP_POS[255:0];
	wire[63:0] MOVE[255:0];
	wire[63:0] Eps_BEG;
	wire[63:0] Eps_BLK;
	wire[63:0] Eps_END;
	wire[63:0] INIT;
	wire[63:0] ACCEPT;
	reg[63:0] STATE;
	reg[63:0] HIGH;
	reg[63:0] LOW;
	reg ready_status,accepted_status;
	wire [1:0] Opcode;
	wire [13:0] Addr;
	integer i;

	initial begin       #cleaning memory the first time around
		for(i =0;i<517;i=i+1)
		{
		 Memory[i] = 0;
		}
		ready_status = 0;
		accepted_status = 0;
		for( i=0;i<256;i=i+1)
		{
			REP_POS[i] = 0;
			MOVE[i]    = 0;
		}
		Eps_BEG = 0;
		Eps_BLK = 0;
		Eps_END = 0;
		INIT    = 0;
		ACCEPT  = 0;
		STATE   = 0;
		HIGH    = 0;
		LOW     = 0;
	end

	#Decoding the Parameters
	assign REP_POS = Memory[255:0];
	assign MOVE    = Memory[511:256];
	assign Eps_BEG = Memory[512];
	assign Eps_BLK = Memory[513];
	assign Eps_END = Memory[514];
	assign INIT    = Memory[515];
	assign ACCEPT  = Memory[516];

	#Breaking down the control signal into opcode and address
	assign Opcode = INP_CONTROL[15:14];
	assign Addr   = INP_CONTROL[13:0];



	always@(posedge clk) begin

		if(DATA_VALID &&(ready_status == 0) && (Addr[13:3] < 517)) begin

			case(Opcode)

				2'b 00: begin					# No Operation Case
							ready_status <= 1;   # make ready_status 1 after processing
					   		accepted_status <= 0;
					   	end

				2'b 01: begin                   # Pre-Processing Case:write bit mask into Memory
							Memory[Addr[13:3]] <= INP_DATA;  #Here I'm ignoring the bottom 3 bits since only the top 11 correspond to the Memory indices
							ready_status <= 1;
							accepted_status <=0;
						end

				2'b 10: begin                   # Simulation Stage : Decode and implement Extended NFA algorithm
							STATE   = 0;     # Change to INIT if wrong

							#Implementing Extended NFA algo

							STATE = (((STATE << 1)| INIT) & MOVE[INP_DATA[7:0]])|(STATE & REP_POS[INP_DATA[7:0]]); #The alpha transitions, assuming INP_DATA is the character
							HIGH  = STATE | Eps_END;
							LOW   = HIGH - Eps_BEG;
							STATE = (Eps_BLK &((~ LOW) ^ HIGH)) | STATE;

							#Testing if Pattern Matching was a success
							if(STATE & ACCEPT)
								accepted_status <= 1;

							else
								accepted_status <= 0;

							ready_status <= 1;

						end

				2'b 11: begin                     #Reset Case : Set STATE to INIT
							STATE <= INIT;
							ready_status <= 1;
							accepted_status <= 0;
						end

			endcase
	 	end
	end


	#assigning the outputs
	assign READY_STATUS = ready_status;
	assign ACCEPTED_STATUS = accepted_status;

endmodule
