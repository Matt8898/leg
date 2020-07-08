#include "defines.inc"

module microcode_unit(input logic clk, input logic reset, output logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr, input logic [(UOP_BUF_WIDTH - 1): 0] uop);
    logic flush_pipeline;
    assign flush_pipeline = 0;

    logic fetch_stalled, fetch_valid;
    logic [31:0] instruction_1;
    logic [31:0] instruction_2;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_1;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_2;

    uop_fetch uf(
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(fetch_stalled),
        .next_stalled(1'b0),
        .valid(fetch_valid),
        .uop_addr(uop_addr),
        .uop(uop),
        .prev_valid(1'b1), //for now stub this
        .instruction_1(instruction_1),
        .instruction_2(instruction_2),
        .branch_tag_1(branch_tag_1),
        .branch_tag_2(branch_tag_2)
    );

    always @(posedge clk) begin
        if(fetch_valid) begin
            $display("fetched %x %x %x %x", instruction_1, instruction_2, branch_tag_1, branch_tag_2);
        end
    end
endmodule
