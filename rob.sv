#include "defines.inc"

`ifndef ROB_H
`define ROB_H

/*
 * used in the issue and commit stage
 * on issue write to entries in the rob,
 * on commit:
 * 1: write the architectural -> physical mapping to the commit register allocation table.
 * 2: free up the previous physical register for the architectural register the instruction writes to.
 * 3: handle exceptions
 */

typedef struct packed {
    logic valid;
    //the instruction is currently running
    logic busy;
    //Registers that the instruction writes to
    logic [$clog2(NUM_PREGS) - 1:0] preg;
    logic [$clog2(NUM_AREGS) - 1:0] areg;
    //the entry caused an exception
    logic exception;
    //is the instruction a valid beginning or end of a macro-instruction
    //this is used in order to determine if execution can be interrupted
    logic macroop_start;
    logic macroop_end;
} reorder_buffer;
`endif
