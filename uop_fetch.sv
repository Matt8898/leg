#include "defines.inc"
#include "instruction.sv"

module uop_fetch (
    input logic clk,
    input logic reset,
    input logic clear,
    output logic stalled, input logic next_stalled, output logic valid, input logic prev_valid,
    output logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr, input logic [(UOP_BUF_WIDTH - 1):0] uop,
    output fetched_instruction instruction_1,
    output fetched_instruction instruction_2
);

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
            instruction_1.instruction <= uop[31:0];
            instruction_2.instruction <= uop[63:32];
            instruction_1.branch_tag <= uop[64 + MAX_PREDICT_DEPTH_BITS * 2 - 1:64 + MAX_PREDICT_DEPTH_BITS];
            instruction_2.branch_tag <= uop[64 + MAX_PREDICT_DEPTH_BITS:64];
            valid <= 1;
            uop_addr <= uop_addr + 1;
        end else begin
            valid <= 0;
            stalled <= 1;
        end
    end
end

endmodule
