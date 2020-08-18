#include "defines.inc"
#include "instruction.sv"
#include "rob.sv"
#define NUM_STAGES 3

module microcode_unit (input logic clk, input logic reset, output logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr, input instruction_bundle uop);
    logic flush_pipeline;
    assign flush_pipeline = 0;

    logic fetch_stalled, fetch_valid;
    logic decode_stalled, decode_valid;
    logic issue_stalled, issue_valid;
    fetched_instruction instruction_1;
    fetched_instruction instruction_2;

    /*
     * pipeline logic
     * the variables that describe a generic stage are:
     * valid, stalled and enabled
     *
     * a stage is stalled if the stage after it is stalled and
     * the stage's output is valid, this is because if the output
     * of the stage isn't valid it means it already passed its
     * output to the next stage, so it's able to take more input,
     * or stage-specific conditions are met (such as being out of registers)
     *
     * a stage is enabled if it's not stalled and the previous' stage
     * input is valid.
     * if a stage is not enabled but the one after it is then the stage's
     * output is not valid anymore, because the next stage is processing it.
     */

    //pipeline variables
    logic stage_enabled[NUM_STAGES - 1:0];
    assign stage_enabled[0] = !fetch_stalled;
    assign stage_enabled[1] = (fetch_valid && !decode_stalled);
    assign stage_enabled[2] = (decode_valid && !issue_stalled);

    /*
     * fetch instructions from the uop buffer.
     */
    uop_fetch uf(
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(fetch_stalled),
        .next_stalled(decode_stalled),
        .valid(fetch_valid),
        .prev_valid(1'b1), //for now stub this
        .enabled(stage_enabled[0]),
        .next_enabled(stage_enabled[1]),
        .uop_addr(uop_addr),
        .uop(uop),
        .instruction_1(instruction_1),
        .instruction_2(instruction_2)
    );

    decoded_instruction decoded_1;
    decoded_instruction decoded_2;
    logic [$clog2(NUM_PREGS) - 1:0] preg1;
    logic [$clog2(NUM_PREGS) - 1:0] preg2;
    logic [1:0] num_execute;
    logic branch_shootdown;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] shootdown_branch_tag;

    input logic free1;
	input logic free2;
	input logic [$clog2(NUM_PREGS) - 1:0] free1_addr;
	input logic [$clog2(NUM_PREGS) - 1:0] free2_addr;

    /*
     * Decode the instructions while also getting the necessary physical
     * registers for them.
     * TODO: maybe move the freelist out of this module to make freeing
     * registers in the commit stage cleaner.
     */
    uop_decode ud (
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(decode_stalled),
        .next_stalled(issue_stalled),
        .valid(decode_valid),
        .prev_valid(fetch_valid),
        .enabled(stage_enabled[1]),
        .next_enabled(stage_enabled[2]),
        .instruction_1(instruction_1),
        .instruction_2(instruction_2),
        .decoded_1(decoded_1),
        .decoded_2(decoded_2),
        .preg1(preg1),
        .preg2(preg2),
        .num_execute(num_execute),
        .branch_shootdown(branch_shootdown),
        .shootdown_branch_tag(shootdown_branch_tag),
        .free1(free1),
        .free2(free2),
        .free1_addr(free1_addr),
        .free2_addr(free2_addr)
    );

    logic [$clog2(ROB_ENTRIES):0] num_free;
    reorder_buffer r[ROB_ENTRIES - 1:0];

    logic branch_shootdown;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] shootdown_branch_tag;
    rat rtable;

    /*
     * End of the in-order part of the pipeline, complete zero-cycle
     * instructions, rename the registers in the temporary RAT and
     * issue other instructions to issue queue.
     *
     * Write register mappings to the retirement rat,
     * issue branch shootdown signals and perform all
     * non-reversible operations.
     */
    uop_issue_commit uic (
        .clk(clk),
        .reset(reset),
        .clear(flush_pipeline),
        .stalled(issue_stalled),
        .next_stalled(1'b0),
        .valid(issue_valid),
        .prev_valid(decode_valid),
        .enabled(stage_enabled[2]),
        .instr_1(decoded_1),
        .instr_2(decoded_2),
        .rob(r),
        .rtable(rtable),
        .num_execute(num_execute),
        .preg1(preg1),
        .preg2(preg2),
        .freelist_branch_shootdown(branch_shootdown),
        .freelist_shootdown_branch_tag(shootdown_branch_tag),
        .free1(free1),
        .free2(free2),
        .free1_addr(free1_addr),
        .free2_addr(free2_addr)
    );

    //debug logic
    always @(posedge clk) begin
        if(fetch_valid) begin
            $display("fetched %x %x %x %x", instruction_1.instruction, instruction_2.instruction, instruction_1.branch_tag, instruction_2.branch_tag);
        end
        if(decode_valid && (!decoded_1.is_noop || !decoded_1.is_noop && !(decoded_1.rs_station == 0 || decoded_2.rs_station == 0))) begin
            $display("decoded - %x %x %x %x", decoded_1.rs_station, decoded_2.rs_station, preg1, preg2);
        end
    end
endmodule
