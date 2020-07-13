#include "defines.inc"

`ifndef INSTRUCTION_H
`define INSTRUCTION_H

typedef struct packed {
    logic [31:0] instruction;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag;
} fetched_instruction;

typedef struct packed {
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag;
    logic [31:0] op;
    logic [5:0] operation;
    logic [4:0] register_target;
    logic [4:0] register_1;
    logic [4:0] register_2;
    logic [25:0] jump_offset;
    logic [10:0] sub_field;
    logic [15:0] immediate;
    logic [3:0]  rs_station;
    logic [5:0] alu_fn;
    logic has_register_1;
    logic has_register_2;
    logic has_target;
	logic is_noop;
} decoded_instruction;
`endif
