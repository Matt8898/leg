#define delay #
#include "defines.inc"

module test;
   logic [(UOP_BUF_WIDTH - 1):0] uops[0:(UOP_BUF_SIZE - 1)];

    logic [31:0] in1 = 'h25270004;
    logic [31:0] in2 = 'h25270005;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_1 = 2;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_2 = 2;

    initial
    begin
        $dumpfile("test.vcd");
        $dumpvars(0, mc);
//        $readmemh("memfile.dat", uops);
        for(int i = 0; i < 128; i++) begin
            uops[i] = 0;
        end

        //temporary to test branch tags
        uops[0] = {branch_tag_1, branch_tag_2, in1, in2};
        $display("%x", uops[0]);
    end


    /* Make a reset that pulses once. */
    logic reset = 0;
    initial begin
        delay 0 reset = 1;
        delay 1 reset = 0;
        delay 2 reset = 1;
        delay 3 reset = 0;
    end

    logic clk = 0;
    logic [31:0] cnt;
    always #5 clk = !clk;
    logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr;
    logic [(UOP_BUF_WIDTH - 1):0] uop;

    assign uop = uops[uop_addr];
    microcode_unit mc(.clk(clk), .reset(reset), .uop_addr(uop_addr), .uop(uop));
endmodule
