#include "defines.inc"

interface freelist (
    input logic clk,
    input logic reset,
    input logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_1,
    input logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_2,
    output logic [$clog2(NUM_PREGS) - 1:0] preg1,
    output logic [$clog2(NUM_PREGS) - 1:0] preg2,
    output logic [$clog2(NUM_PREGS):0] num_free,
    input logic branch_shootdown,
    input logic [MAX_PREDICT_DEPTH_BITS - 1:0] shootdown_branch_tag,
	input logic free1,
	input logic free2,
	input logic [$clog2(NUM_PREGS) - 1:0] free1_addr,
	input logic [$clog2(NUM_PREGS) - 1:0] free2_addr
);

logic[NUM_PREGS - 1:0] list;
logic [$clog2(NUM_PREGS):0] i_num_free;
//TODO add a table for the validity of the branch lists.
logic[NUM_PREGS - 1:0] branch_lists[MAX_PREDICT_DEPTH - 1:0];
logic[NUM_PREGS - 1:0] branch_shootdown_mask;

assign num_free = i_num_free;

integer i;
integer j;
always_comb begin
    i_num_free = 0;
    for(i = 0; i < NUM_PREGS; i = i + 1) begin
        if(list[i] == 1) begin
            i_num_free = i_num_free + 1;
        end
    end
end

logic [$clog2(NUM_PREGS) - 1:0] first_free;
logic [$clog2(NUM_PREGS) - 1:0] second_free;

always_comb begin
    for(i = 0; i < NUM_PREGS; i = i + 1) begin
        if(list[i] == 1) begin
            first_free = i;
        end
    end
    for(i = 0; i < NUM_PREGS; i = i + 1) begin
        if(list[i] == 1 && i != first_free) begin
            second_free = i;
        end
    end
end

assign preg1 = first_free;
assign preg2 = second_free;

always_comb begin
    branch_shootdown_mask = 0;
    for(i = 0; i < MAX_PREDICT_DEPTH; i = i + 1) begin
        if((i - 1) >= shootdown_branch_tag) begin
            branch_shootdown_mask = branch_shootdown_mask & branch_lists[shootdown_branch_tag - 1];
        end
    end
end

genvar k;
genvar l;
generate
	for(k = 0; k < NUM_PREGS; k = k + 1) begin
		always @(posedge clk) begin
			if(reset) list[k] <= 1;
		end
		for(l = 0; l < MAX_PREDICT_DEPTH; l = l + 1) begin
			always @(posedge clk) begin
				if(reset) branch_lists[l][k] <= 1;
			end
		end
	end
endgenerate

always @(posedge clk) begin
	if(branch_shootdown) begin
        list <= list | ~(branch_shootdown_mask);
    end
end

always @(posedge clk) begin
	if(free1) begin
		$display("freelist: freeing register: %x", free1_addr);
		list[free1_addr] <= 1;
	end
	if(free2) begin
		$display("freelist: freeing register: %x", free2_addr);
		list[free2_addr] <= 1;
	end
end

task allocate(input logic [1:0] _num_pull);
	begin
//        assert(i_num_free >= _num_pull);
        if(_num_pull == 1) begin
            list[first_free] <= 0;
            if(branch_tag_1 != 0) begin
                branch_lists[branch_tag_1 - 1][first_free] <= 0;
            end
        end else if(_num_pull == 2) begin
            list[first_free] <= 0;
            list[second_free] <= 0;
            if(branch_tag_1 != 0) begin
                branch_lists[branch_tag_1 - 1][first_free] <= 0;
            end
            if(branch_tag_2 != 0) begin
                branch_lists[branch_tag_2 - 1][second_free] <= 0;
            end
        end
    end
endtask

endinterface
