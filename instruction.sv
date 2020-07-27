#include "defines.inc"

`ifndef INSTRUCTION_H
`define INSTRUCTION_H

typedef struct packed {
    logic [31:0] instruction;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag;
    logic macroop_start;
    logic macroop_end;
} fetched_instruction;

typedef struct packed {
    fetched_instruction i1;
    fetched_instruction i2;
} instruction_bundle;

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
    //instruction moves a reigster to another register
    logic reg_reg_mov;
    logic is_noop;
    //the instruction can run with no reservation station usage.
    logic is_zerocycle;
    logic has_reg1;
    logic has_reg2;
    logic has_target;
    logic macroop_start;
    logic macroop_end;
} decoded_instruction;
`endif
