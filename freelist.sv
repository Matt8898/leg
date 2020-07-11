#include "defines.inc"

module freelist(
    input logic clk,
    input logic reset,
    input logic [1:0] num_pull,
    output logic [$clog2(NUM_PREGS) - 1:0] preg1,
    output logic [$clog2(NUM_PREGS) - 1:0] preg2,
    output logic [$clog2(NUM_PREGS):0] num_free
);

logic[NUM_PREGS - 1:0] list;
logic [$clog2(NUM_PREGS):0] i_num_free;

assign num_free = i_num_free;

integer i;
always_comb begin
    i_num_free = 0;
    for(i = 0; i < NUM_PREGS; i = i + 1) begin
        if(list[i] == 1) begin
            $display("bit 1");
            i_num_free = num_free + 1;
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


always @(posedge clk) begin
    if(reset) begin
        for(i = 0; i < NUM_PREGS; i = i + 1) begin
            list[i] <= 1;
        end
    end else begin
        assert(i_num_free >= num_pull);
        if(num_pull == 1) begin
            preg1 <= first_free;
            list[first_free] <= 0;
        end else if(num_pull == 2) begin
            preg1 <= first_free;
            preg2 <= second_free;
            list[first_free] <= 0;
            list[second_free] <= 0;
       end
    end
end

endmodule
