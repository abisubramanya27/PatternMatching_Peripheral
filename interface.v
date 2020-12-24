module interface(
    input clk,
    input dwdata
    input dwe,
    input daddr,
    output rdata 
);
    
    reg [63:0] data_buffer;
    reg [63:0] pmm_data[0:3];
    reg [15:0] pmm_control[0:3];
    
    reg [7:0] mem0[0:5];  
    reg [7:0] mem1[0:5];  
    reg [7:0] mem2[0:5];  
    reg [7:0] mem3[0:5];  

    wire [29:0] a;
    assign a = daddr[31:2];

    initial begin  
        for (i=0; i<6; i=i+1) begin
            mem0[i] = 0;
            mem1[i] = 0;
            mem2[i] = 0;
            mem3[i] = 0;
        end
    end
    
    always @(posedge clk) begin
        if (dwe != 0) begin
            case(a)
                0:begin
                    mem0[0] = dwdata[7:0];
                    mem1[0] = dwdata[15:8];
                    mem2[0] = dwdata[23:16];
                    mem3[0] = dwdata[31:24];                    
                    data_buffer[31:0]=dwdata;
                end
                1:begin
                    mem0[1] = dwdata[7:0];
                    mem1[1] = dwdata[15:8];
                    mem2[1] = dwdata[23:16];
                    mem3[1] = dwdata[31:24];                    
                    data_buffer[63:32]=dwdata;
                end
                2:begin
                    mem0[2] = dwdata[7:0];
                    mem1[2] = dwdata[15:8];
                    mem2[2] = dwdata[23:16];
                    mem3[2] = dwdata[31:24]; 
                    if ({ mem1[2], mem0[2]}==16'h00) begin
                        pmm_data[0]=data_buffer;
                        pmm_control[0]={ mem3[2], mem2[2]};
                        case(mem3[2][7:6])
                            2'b00:begin
                                mem0[3][0]=0;
                            end
                            2'b01,2'b10,2'b11:begin
                                mem0[3][0]=1;
                            end
                        endcase                        
                    end
                    else if ({ mem1[2], mem0[2]}==16'h01) begin
                        pmm_data[1]=data_buffer;
                        pmm_control[1]={ mem3[2], mem2[2]};
                        case(mem3[2][7:6])
                            2'b00:begin
                                mem0[3][1]=0;
                            end
                            2'b01,2'b10,2'b11:begin
                                mem0[3][1]=1;
                            end
                        endcase                           
                    end
                    else if ({ mem1[2], mem0[2]}==16'h02) begin
                        pmm_data[2]=data_buffer;
                        pmm_control[2]={ mem3[2], mem2[2]};
                        case(mem3[2][7:6])
                            2'b00:begin
                                mem0[3][2]=0;
                            end
                            2'b01,2'b10,2'b11:begin
                                mem0[3][2]=1;
                            end
                        endcase                           
                    end
                    else if ({ mem1[2], mem0[2]}==16'h03) begin
                        pmm_data[3]=data_buffer;
                        pmm_control[3]={ mem3[2], mem2[2]};
                        case(mem3[2][7:6])
                            2'b00:begin
                                mem0[3][3]=0;
                            end
                            2'b01,2'b10,2'b11:begin
                                mem0[3][3]=1;
                            end
                        endcase
                    end
                end 
            endcase
        end
    end
    always @(mem0[4][0]) begin
        if(mem0[4][0]==1) begin
            mem0[3][0]=0;
        end
    end
    always @(mem0[4][1]) begin
        if(mem0[4][1]==1) begin
            mem0[3][1]=0;
        end
    end
    always @(mem0[4][2]) begin
        if(mem0[4][2]==1) begin
            mem0[3][2]=0;
        end
    end   
    always @(mem0[4][3]) begin
        if(mem0[4][3]==1) begin
            mem0[3][3]=0;
        end
    end   
            
                        
                                                            
                    
            
            
            
            
            
            
            
    
    
    
    