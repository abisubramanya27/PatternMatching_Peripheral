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

    reg [7:0] mem0[0:4];
    reg [7:0] mem1[0:4];
    reg [7:0] mem2[0:4];
    reg [7:0] mem3[0:4];

    wire [29:0] a;
    assign a = daddr[31:2];

    initial begin
        for (i=0; i<5; i=i+1) begin
            mem0[i] = 0;
            mem1[i] = 0;
            mem2[i] = 0;
            mem3[i] = 0;
        end
    end

    always(posedge clk) begin
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
                    end
                    else if ({ mem1[2], mem0[2]}==16'h01) begin
                        pmm_data[1]=data_buffer;
                        pmm_control[1]={ mem3[2], mem2[2]};
                    end
                    else if ({ mem1[2], mem0[2]}==16'h02) begin
                        pmm_data[2]=data_buffer;
                        pmm_control[2]={ mem3[2], mem2[2]};
                    end
                    else if ({ mem1[2], mem0[2]}==16'h03) begin
                        pmm_data[3]=data_buffer;
                        pmm_control[3]={ mem3[2], mem2[2]};
                    end
                end
            endcase
        end
    end
















    
