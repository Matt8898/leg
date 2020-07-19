#include "defines.inc"

interface rat(
    input logic clk,
    input logic reset,
    input logic branch_shootdown,
    input logic [MAX_PREDICT_DEPTH_BITS - 1:0] shootdown_branch_tag
);

//commited state of the registers, used for interrupts and exceptions
logic [$clog2(NUM_PREGS) - 1:0] commit_reg_table[NUM_AREGS - 1:0];
//speculative state of the registers
logic [$clog2(NUM_PREGS) - 1:0] reg_table[NUM_AREGS - 1:0];
logic [$clog2(NUM_PREGS) - 1:0] branch_tables[NUM_AREGS - 1:0][MAX_PREDICT_DEPTH - 1:0];
logic branch_table_valid[MAX_PREDICT_DEPTH - 1:0];

integer i;
integer j;
always @(posedge clk) begin
    if(reset) begin
        for(i = 0; i < NUM_AREGS; i++) begin
            reg_table[i] <= 0;
            for(j = 0; j < MAX_PREDICT_DEPTH; j++) begin
                branch_tables[j][i] <= 0;
            end
        end
        for(j = 0; j < MAX_PREDICT_DEPTH; j++) begin
            branch_table_valid[j] <= 0;
        end
    end else begin
        if(branch_shootdown) begin
            for(j = 0; j < MAX_PREDICT_DEPTH; j++) begin
                if((j - 1) >= shootdown_branch_tag) begin
                    branch_table_valid[j] <= 0;
                end
            end
        end
    end
end

task map(input logic [$clog2(NUM_AREGS) - 1:0] arch, input logic [$clog2(NUM_PREGS) - 1:0] phys, input logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag);
    if(branch_tag == 0) begin
        reg_table[arch] <= phys;
    end else begin
        if(branch_table_valid[branch_tag - 1]) begin
            branch_tables[branch_tag - 1][arch] <= phys;
        end else begin
            //TODO check conflicts between this and branch shootdown.
            //in theory it shouldn't happen given that shootdown is handled in
            //the issue stage.
            branch_table_valid[branch_tag - 1] <= 1;
            //copy the main table
            if(branch_tag == 1) begin
                for(i = 0; i < NUM_AREGS; i++) begin
                    if(i != arch) begin
                        branch_tables[branch_tag - 1][i] <= reg_table[i];
                    end else begin
                        branch_tables[branch_tag - 1][i] <= phys;
                    end
                end
            end else begin
                //copy the previous branch table
                for(i = 0; i < NUM_AREGS; i++) begin
                    if(i != arch) begin
                        branch_tables[branch_tag - 1][i] <= branch_tables[branch_tag - 2][i];
                    end else begin
                        branch_tables[branch_tag - 1][i] <= phys;
                    end
                end
            end
        end
    end
endtask

task get(input logic [$clog2(NUM_AREGS) - 1:0] arch, input logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag, output logic [$clog2(NUM_PREGS) - 1:0] phys);
    if(branch_tag == 0) begin
        phys = reg_table[arch];
    end else begin
        assert(branch_table_valid[branch_tag - 1]);
        phys = branch_tables[branch_tag - 1][arch];
    end
endtask

endinterface
