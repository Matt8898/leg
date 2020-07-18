#include "defines.inc"

/*
 * used in the issue and commit stage
 * on issue write to entries in the rob,
 * on commit:
 * 1: write the architectural -> physical mapping to the commit register allocation table.
 * 2: free up the previous physical register for the architectural register the instruction writes to.
 * 3: handle exceptions
 */

interface rob;

logic valid[ROB_ENTRIES - 1:0];
//the instruction is currently running
logic busy[ROB_ENTRIES - 1:0];
//Registers that the instruction writes to
logic [$clog2(NUM_PREGS) - 1:0] preg[ROB_ENTRIES - 1:0];
logic [$clog2(NUM_AREGS) - 1:0] areg[ROB_ENTRIES - 1:0];
//the entry caused an exception
logic exception[ROB_ENTRIES - 1:0];
//is the instruction a valid beginning or end of a macro-instruction
//this is used in order to determine if execution can be interrupted
logic macroop_begin[ROB_ENTRIES - 1:0];
logic macroop_end[ROB_ENTRIES - 1:0];

endinterface
