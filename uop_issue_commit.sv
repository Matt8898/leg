#include "defines.inc"
#include "instruction.sv"
#include "rob.sv"

module uop_issue_commit (
    input logic clk,
    input logic reset,
    input logic clear,
    output logic stalled, input logic next_stalled, output logic valid, input logic prev_valid, input logic enabled,
    input decoded_instruction instr_1,
    input decoded_instruction instr_2,
    input logic [$clog2(NUM_PREGS) - 1:0] preg1,
    input logic [$clog2(NUM_PREGS) - 1:0] preg2,
    output reorder_buffer rob[ROB_ENTRIES - 1:0],
    inout rat rtable,
    input logic [1:0] num_execute,
	output logic freelist_branch_shootdown,
	output logic [MAX_PREDICT_DEPTH_BITS - 1:0] freelist_shootdown_branch_tag,
	output logic free1,
	output logic free2,
	output logic [$clog2(NUM_PREGS) - 1:0] free1_addr,
	output logic [$clog2(NUM_PREGS) - 1:0] free2_addr
);

logic [5:0] stall_time;
logic i_stalled;
logic [$clog2(ROB_ENTRIES):0] rob_free;
logic [$clog2(NUM_AREGS) - 1:0] rob_entry;

logic branch_shootdown;
logic [MAX_PREDICT_DEPTH_BITS - 1:0] shootdown_branch_tag;

assign i_stalled = num_execute > rob_free;

always_comb begin
    stalled = i_stalled;
end

always_comb begin
    rob_free = 0;
    for(int i = 0; i < ROB_ENTRIES; i++) begin
        if(!rob[i].valid) begin
            rob_free++;
        end
    end
end

always @(posedge clk) begin
    if(reset) begin
        free1 <= 0;
        free2 <= 0;
        freelist_branch_shootdown <= 0;
        freelist_shootdown_branch_tag <= 0;
        for(int i = 0; i < ROB_ENTRIES; i++) begin
            rob[i].valid <= 0;
            rob[i].busy <= 0;
            rob[i].preg <= 0;
            rob[i].areg <= 0;
            rob[i].exception <= 0;
            rob[i].macroop_start <= 0;
            rob[i].macroop_end <= 0;
        end
    end
end

/*
 * rat logic
 */
generate
genvar j;
genvar k;
for(j = 0; j < NUM_AREGS; j++) begin
    always @(posedge clk) begin
        if(reset) begin
            rtable.reg_table[j] <= 0;
        end
    end
end
for(j = 0; j < NUM_AREGS; j++) begin
    for(k = 0; k < MAX_PREDICT_DEPTH; k++) begin
        always @(posedge clk) begin
            if(reset) begin
                rtable.branch_tables[k][j] <= 0;
            end
        end
    end
end
for(k = 0; k < MAX_PREDICT_DEPTH; k++) begin
    always @(posedge clk) begin
        if(reset) begin
            rtable.branch_table_valid[k] <= 0;
        end
    end
end

for(k = 0; k < MAX_PREDICT_DEPTH; k++) begin
    always @(posedge clk) begin
        if(branch_shootdown) begin
            if((k - 1) >= shootdown_branch_tag) begin
                rtable.branch_table_valid[k] <= 0;
            end
        end
    end
end
endgenerate

task map(input logic [$clog2(NUM_AREGS) - 1:0] arch, input logic [$clog2(NUM_PREGS) - 1:0] phys, input logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag);
    $display("mapping register %x to %x", arch, phys);
    if(branch_tag == 0) begin
        rtable.reg_table[arch] <= phys;
    end else begin
        if(rtable.branch_table_valid[branch_tag - 1]) begin
            rtable.branch_tables[branch_tag - 1][arch] <= phys;
        end else begin
            //TODO check conflicts between this and branch shootdown.
            //in theory it shouldn't happen given that shootdown is handled in
            //the issue stage.
            rtable.branch_table_valid[branch_tag - 1] <= 1;
            //copy the main table
            if(branch_tag == 1) begin
                for(int i = 0; i < NUM_AREGS; i++) begin
                    if(i != arch) begin
                        rtable.branch_tables[branch_tag - 1][i] <= rtable.reg_table[i];
                    end else begin
                        rtable.branch_tables[branch_tag - 1][i] <= phys;
                    end
                end
            end else begin
                //copy the previous branch table
                for(int i = 0; i < NUM_AREGS; i++) begin
                    if(i != arch) begin
                        rtable.branch_tables[branch_tag - 1][i] <= rtable.branch_tables[branch_tag - 2][i];
                    end else begin
                        rtable.branch_tables[branch_tag - 1][i] <= phys;
                    end
                end
            end
        end
    end
endtask

task rat_get(input logic [$clog2(NUM_AREGS) - 1:0] arch, input logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag, output logic [$clog2(NUM_PREGS) - 1:0] phys);
    if(branch_tag == 0) begin
        phys = rtable.reg_table[arch];
    end else begin
        assert(rtable.branch_table_valid[branch_tag - 1]);
        phys = rtable.branch_tables[branch_tag - 1][arch];
    end
endtask

/*
 * Stage logic
 */
always @(posedge clk) begin
    if(reset || clear) begin
        valid <= 0;
        stall_time <= 0;
        rob_entry <= 0;
    end else begin
        if(enabled) begin
            $display("num_execute: %x", num_execute);
            valid <= prev_valid;
            //fill reorder buffer entries
            if(instr_1.rs_station != 0 && !instr_1.is_noop) begin
                $display("1: writing to rob entry %x", rob_entry);
                rob[rob_entry].valid <= 1;
                //if the instruction is zero-cycle (register register move for example, setting the rob entries is all that's necessary)
                $display("instruction 1 zero cycle: %x at rob entry %x", instr_1.is_zerocycle, rob_entry);
                rob[rob_entry].busy <= !instr_1.is_zerocycle;
                rob[rob_entry].preg <= preg1;
                rob[rob_entry].areg <= instr_1.register_target;
                rob[rob_entry].macroop_start <= instr_1.macroop_start;
                rob[rob_entry].macroop_end <= instr_1.macroop_end;
            end
            if(instr_1.rs_station != 0 && !instr_1.is_noop) begin
                $display("2: writing to rob entry %x", rob_entry + 1);
                $display("instruction 2 zero cycle: %x at rob entry: %x", instr_2.is_zerocycle, rob_entry + 1);
                rob[rob_entry + 1].valid <= 1;
                rob[rob_entry + 1].busy <= !instr_2.is_zerocycle;
                rob[rob_entry + 1].preg <= preg2;
                rob[rob_entry + 1].areg <= instr_2.register_target;
                rob[rob_entry + 1].macroop_start <= instr_2.macroop_start;
                rob[rob_entry + 1].macroop_end <= instr_2.macroop_end;
            end

            //TODO issue to issue queues and check registers

            //map registers in the current rat, making sure to handle two
            //instructions writing to the same register.
            if(num_execute == 2) begin
                if(instr_1.register_target == instr_2.register_target) begin
                    map(instr_2.register_target, preg2, instr_2.branch_tag);
                end else begin
                    map(instr_1.register_target, preg1, instr_1.branch_tag);
                    map(instr_2.register_target, preg2, instr_2.branch_tag);
                end
            end else if(num_execute == 1) begin
                map(instr_1.register_target, preg1, instr_1.branch_tag);
            end
            rob_entry <= rob_entry + num_execute;
        end
    end
end

logic [$clog2(ROB_ENTRIES) - 1:0] commit_rob_entry;
//the processor's actual renaming state at any given point
logic [$clog2(NUM_PREGS) - 1:0] committed_rat[NUM_AREGS - 1:0];

always @(posedge clk) begin
    if(reset) begin
        commit_rob_entry <= 0;
    end else begin
        $display("1: rob entry 0: %x %x %x", rob[commit_rob_entry].valid, rob[commit_rob_entry].busy, commit_rob_entry);
        $display("2: rob entry 1: %x %x %x", rob[commit_rob_entry + 1].valid, rob[commit_rob_entry + 1].busy, commit_rob_entry + 1);
        if(rob[commit_rob_entry].valid && !rob[commit_rob_entry].busy) begin
            $display("1: An instruction is ready to commit");
            $display("1: Architectural register %x renamed to %x", rob[commit_rob_entry].areg, rob[commit_rob_entry].preg);
            /*
             * Check if an architectural register has been written to by
             * another instruction before, if this is true then we can free
             * the previous physical register, doing this holds up registers
             * for longer than necessary but makes the logic a lot simpler.
             */
            if(committed_rat[rob[commit_rob_entry].areg] != 0) begin
                $display("1: freeing register %x", committed_rat[rob[commit_rob_entry].preg]);
                free1_addr <= rob[commit_rob_entry].preg;
                free1 <= 1;
            end
            if((rob[commit_rob_entry + 1].valid && !rob[commit_rob_entry + 1].busy) && (rob[commit_rob_entry + 1].areg != rob[commit_rob_entry].areg)) begin
                committed_rat[rob[commit_rob_entry].areg] <= rob[commit_rob_entry].preg;
            end
            rob[commit_rob_entry].valid <= 0;
            rob[commit_rob_entry].busy <= 0;
        end

        if(rob[commit_rob_entry + 1].valid && !rob[commit_rob_entry + 1].busy) begin
                $display("2: An instruction is ready to commit");
                $display("2: Architectural register %x renamed to %x", rob[commit_rob_entry + 1].areg, rob[commit_rob_entry + 1].preg);
                /*
                 * Check if an architectural register has been written to by
                 * another instruction before, if this is true then we can free
                 * the previous physical register, doing this holds up registers
                 * for longer than necessary but makes the logic a lot simpler.
                 */
                if(committed_rat[rob[commit_rob_entry + 1].areg] != 0) begin
                    $display("2: freeing register %x", committed_rat[rob[commit_rob_entry + 1].preg]);
                    free2 <= 1;
                    free2_addr <= rob[commit_rob_entry + 1].preg;
                end
                if(rob[commit_rob_entry + 1].areg == rob[commit_rob_entry].areg) begin
                    $display("2: freeing register %x", rob[commit_rob_entry].preg);
                    free1 <= 1;
                    free1_addr <= rob[commit_rob_entry].preg;
                end
                committed_rat[rob[commit_rob_entry + 1].areg] <= rob[commit_rob_entry + 1].preg;
                rob[commit_rob_entry + 1].valid <= 0;
                rob[commit_rob_entry + 1].busy <= 0;
            end
    end
end
    always @(posedge clk) begin
        if(free1) free1 <= 0;
        if(free2) free2 <= 0;
    end

endmodule
