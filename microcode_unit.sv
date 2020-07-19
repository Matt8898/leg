#include "defines.inc"
#include "instruction.sv"

module microcode_unit (input logic clk, input logic reset, output logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr, input instruction_bundle uop);
    logic flush_pipeline;
    assign flush_pipeline = 0;

    logic fetch_stalled, fetch_valid;
    logic decode_stalled, decode_valid;
    logic issue_stalled, issue_valid;
    fetched_instruction instruction_1;
    fetched_instruction instruction_2;

    uop_fetch uf(
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(fetch_stalled),
        .next_stalled(decode_stalled),
        .valid(fetch_valid),
        .prev_valid(1'b1), //for now stub this
        .uop_addr(uop_addr),
        .uop(uop),
        .instruction_1(instruction_1),
        .instruction_2(instruction_2)
    );

    decoded_instruction decoded_1;
    decoded_instruction decoded_2;
    logic [$clog2(NUM_PREGS) - 1:0] preg1;
    logic [$clog2(NUM_PREGS) - 1:0] preg2;

    uop_decode ud (
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(decode_stalled),
        .next_stalled(issue_stalled),
        .valid(decode_valid),
        .prev_valid(fetch_valid),
        .instruction_1(instruction_1),
        .instruction_2(instruction_2),
        .decoded_1(decoded_1),
        .decoded_2(decoded_2),
        .preg1(preg1),
        .preg2(preg2)
    );

 	logic [$clog2(ROB_ENTRIES):0] num_free;
	rob rob(clk, reset, num_free);
	busylist bl(clk, reset);

	uop_issue ui (
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(issue_stalled),
        .next_stalled(1'b0),
        .valid(issue_valid),
        .prev_valid(decode_valid)
    );

    always @(posedge clk) begin
        if(fetch_valid) begin
            $display("fetched %x %x %x %x", instruction_1.instruction, instruction_2.instruction, instruction_1.branch_tag, instruction_2.branch_tag);
        end
        if(decode_valid && (!decoded_1.is_noop && !decoded_1.is_noop && !(decoded_1.rs_station == 0 || decoded_2.rs_station == 0))) begin
            $display("decoded - %x %x %x %x", decoded_1.rs_station, decoded_2.rs_station, preg1, preg2);
        end
    end
endmodule
