#include "defines.inc"
#include "instruction.sv"

module uop_fetch (
    input logic clk,
    input logic reset,
    input logic clear,
    output logic stalled, input logic next_stalled, output logic valid, input logic prev_valid,
    input logic enabled, input logic next_enabled,
    output logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr, input instruction_bundle uop,
    output fetched_instruction instruction_1,
    output fetched_instruction instruction_2
);

always_comb begin
    stalled = prev_valid && next_stalled;
end

always @(posedge clk) begin
    if(reset) begin
        uop_addr <= 0;
        valid <= 0;
    end else begin
        if(clear) begin
            uop_addr <= 0;
            valid <= 0;
        end else if(enabled) begin
            instruction_1 <= uop.i1;
            instruction_2 <= uop.i2;
            valid <= prev_valid;
            uop_addr <= uop_addr + 1;
        end else if(next_enabled) begin
            valid <= 0;
        end
    end
end

endmodule
