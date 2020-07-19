module uop_issue(
    input logic clk,
    input logic reset,
    input logic clear,
    output logic stalled, input logic next_stalled, output logic valid, input logic prev_valid, input logic enabled
);

logic [5:0] stall_time;
logic i_stalled;

always_comb begin
    stalled = 0;
end

always @(posedge clk) begin
    if(reset || clear) begin
        valid <= 0;
        stall_time <= 0;
    end else begin
        if(enabled) begin
            valid <= prev_valid;
        end
    end
end



endmodule
