module microcode_unit(input logic clk, input logic reset, output logic [$clog2(UOP_BUF_SIZE):0] uop_addr, input logic [(UOP_BUF_WIDTH - 1): 0] uop);
    parameter UOP_BUF_SIZE = 128;
    parameter UOP_BUF_WIDTH = 32;

	logic [31:0] instruction_1;
	logic [31:0] instruction_2;

    always @(posedge clk) begin
        if(reset) uop_addr <= 0;
        $display("%x", uop);
    end

endmodule
