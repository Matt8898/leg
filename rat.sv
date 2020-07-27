#include "defines.inc"

`ifndef RAT_H
`define RAT_H

typedef struct packed {
    //speculative state of the registers
    logic [$clog2(NUM_PREGS) - 1:0] reg_table[NUM_AREGS - 1:0];
    logic [$clog2(NUM_PREGS) - 1:0] branch_tables[NUM_AREGS - 1:0][MAX_PREDICT_DEPTH - 1:0];
    logic branch_table_valid[MAX_PREDICT_DEPTH - 1:0];
} rat;
`endif
