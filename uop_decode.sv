#include "defines.inc"
#include "instruction.sv"

module uop_decode (
    input logic clk,
    input logic reset,
    input logic clear,
    output logic stalled, input logic next_stalled, output logic valid, input logic prev_valid,
    input logic enabled, input logic next_enabled,
    input fetched_instruction instruction_1,
    input fetched_instruction instruction_2,
    output decoded_instruction decoded_1,
    output decoded_instruction decoded_2,
    output logic [$clog2(NUM_PREGS) - 1:0] preg1,
    output logic [$clog2(NUM_PREGS) - 1:0] preg2,
    output logic [1:0] num_execute,
	input logic branch_shootdown,
	input logic [MAX_PREDICT_DEPTH_BITS - 1:0] shootdown_branch_tag
);

decoded_instruction i_decoded_1;
decoded_instruction i_decoded_2;

instruction_decoder idec1(instruction_1, i_decoded_1);
instruction_decoder idec2(instruction_2, i_decoded_2);

logic [$clog2(NUM_PREGS):0] num_free;
logic [$clog2(NUM_PREGS) - 1:0] i_preg1;
logic [$clog2(NUM_PREGS) - 1:0] i_preg2;

freelist freelist(
   .clk(clk),
   .reset(reset),
   .branch_tag_1(i_decoded_1.branch_tag),
   .branch_tag_2(i_decoded_2.branch_tag),
   .preg1(i_preg1),
   .preg2(i_preg2),
   .num_free(num_free),
   .branch_shootdown(branch_shootdown),
   .shootdown_branch_tag(shootdown_branch_tag)
);

logic i_stalled;

always_comb begin
    stalled = (valid && next_stalled);
end

//number of registers that need to be pulled
logic [1:0] num_registers;
assign num_registers =
    ((i_decoded_1.is_noop && i_decoded_2.is_noop) || (i_decoded_1.rs_station == 0 && i_decoded_2.rs_station == 0)) ?
        0 :
        (((i_decoded_1.is_noop || i_decoded_2.is_noop) || (i_decoded_1.rs_station == 0 || i_decoded_2.rs_station == 0)) ? 1 : 2);
assign i_stalled = num_free < num_registers;

always @(posedge clk) begin
    if(reset || clear) begin
        valid <= 0;
    end else begin
        if(enabled) begin
            valid <= prev_valid;
            //allocate registers and pipeline the results forward
            freelist.allocate(num_registers);
            decoded_1 <= i_decoded_1;
            decoded_2 <= i_decoded_2;
            preg1 <= i_preg1;
            preg2 <= i_preg2;
            num_execute <= num_registers;
        end else if(next_enabled) begin
            valid <= 0;
        end
    end
end
endmodule
