#include "defines.inc"
#include "instruction.sv"

module microcode_unit (input logic clk, input logic reset, output logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr, input instruction_bundle uop);
    logic flush_pipeline;
    assign flush_pipeline = 0;

    logic fetch_stalled, fetch_valid;
    fetched_instruction instruction_1;
    fetched_instruction instruction_2;

    uop_fetch uf(
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(fetch_stalled),
        .next_stalled(1'b0),
        .valid(fetch_valid),
        .prev_valid(1'b1), //for now stub this
        .uop_addr(uop_addr),
        .uop(uop),
        .instruction_1(instruction_1),
        .instruction_2(instruction_2)
    );

    logic decode_stalled, decode_valid;

    uop_decode ud (
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(decode_stalled),
        .next_stalled(1'b0),
        .valid(decode_valid),
        .prev_valid(fetch_valid),
        .instruction_1(instruction_1),
        .instruction_2(instruction_2)
    );

    always @(posedge clk) begin
        if(fetch_valid) begin
            $display("fetched %x %x %x %x", instruction_1.instruction, instruction_2.instruction, instruction_1.branch_tag, instruction_2.branch_tag);
        end
    end
endmodule
