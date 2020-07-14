#include "defines.inc"
#include "instruction.sv"

module uop_decode (
    input logic clk,
    input logic reset,
    input logic clear,
    output logic stalled, input logic next_stalled, output logic valid, input logic prev_valid,
    input fetched_instruction instruction_1,
    input fetched_instruction instruction_2,
    output decoded_instruction decoded_1,
    output decoded_instruction decoded_2,
    output logic [$clog2(NUM_PREGS) - 1:0] preg1,
    output logic [$clog2(NUM_PREGS) - 1:0] preg2
);

decoded_instruction i_decoded_1;
decoded_instruction i_decoded_2;

instruction_decoder idec1(instruction_1, i_decoded_1);
instruction_decoder idec2(instruction_2, i_decoded_2);

logic [$clog2(NUM_PREGS):0] num_free;
logic branch_shootdown;
logic [MAX_PREDICT_DEPTH_BITS - 1:0] shootdown_branch_tag;

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

always @(posedge clk) begin
    if(reset) begin
        valid <= 0;
        stalled <= 0;
        branch_shootdown <= 0;
        shootdown_branch_tag <= 0;
    end else begin
        if(clear) begin
            valid <= 0;
            stalled <= 0;
        end else if(!next_stalled && prev_valid) begin
            //check if the two instructions have the same destination.
            if((i_decoded_1.is_noop && i_decoded_2.is_noop) || (i_decoded_1.rs_station == 0 && i_decoded_2.rs_station == 0)) begin
                valid <= 0;
            end else if((i_decoded_1.is_noop || i_decoded_2.is_noop) || (i_decoded_1.rs_station == 0 || i_decoded_2.rs_station == 0)) begin
                if(num_free < 1) begin
                    valid <= 0;
                    stalled <= 1;
                end else begin
                    freelist.allocate(1);
                    valid <= 1;
                end
            end else begin
                if(num_free < 2) begin
                    valid <= 0;
                    stalled <= 1;
                end else begin
                    freelist.allocate(2);
                    valid <= 1;
                end
            end
        end else begin
            valid <= 0;
            stalled <= 1;
        end
    end
end

always @(posedge clk) begin
	decoded_1 <= i_decoded_1;
	decoded_2 <= i_decoded_2;
	preg1 <= i_preg1;
	preg2 <= i_preg2;
end

endmodule
