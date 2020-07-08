module uop_fetch (
    input logic clk,
    input logic reset,
    input logic clear,
    output logic stalled, input logic next_stalled, output logic valid, input logic prev_valid,
    output logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr, input logic [(UOP_BUF_WIDTH - 1):0] uop,
    output logic [31:0] instruction_1,
    output logic [31:0] instruction_2,
    output logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_1,
    output logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_2
);

parameter UOP_BUF_SIZE = 128;
parameter MAX_PREDICT_DEPTH = 3;
parameter MAX_PREDICT_DEPTH_BITS = $clog2(MAX_PREDICT_DEPTH);
parameter UOP_BUF_WIDTH = 64 + MAX_PREDICT_DEPTH_BITS * 2;

always @(posedge clk) begin
    if(reset) begin
        uop_addr <= 0;
        valid <= 0;
        stalled <= 0;
    end else begin
        if(clear) begin
            uop_addr <= 0;
            valid <= 0;
            stalled <= 0;
        end else if(!next_stalled && prev_valid) begin
            instruction_1 <= uop[31:0];
            instruction_2 <= uop[63:32];
            branch_tag_1 <= uop[64 + MAX_PREDICT_DEPTH_BITS * 2 - 1:64 + MAX_PREDICT_DEPTH_BITS];
            branch_tag_2 <= uop[64 + MAX_PREDICT_DEPTH_BITS:64];
            valid <= 1;
            uop_addr <= uop_addr + 1;
        end else begin
            valid <= 0;
            stalled <= 1;
        end
    end
end

endmodule
