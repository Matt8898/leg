#define delay #
#include "defines.inc"
#include "instruction.sv"

module test;
   instruction_bundle uops[0:(UOP_BUF_SIZE - 1)];
   instruction_bundle uops0;

    logic [31:0] in1 = 'h25270004;
    logic [31:0] in2 = 'h25270005;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_1 = 2;
    logic [MAX_PREDICT_DEPTH_BITS - 1:0] branch_tag_2 = 2;

    initial
    begin
        $dumpfile("test.vcd");
        $dumpvars(0, mc);
        for(int i = 0; i < 128; i++) begin
            uops[i] = 0;
        end

        uops[0][71-:32] = 'h25270004;
        uops[0][39-:2] = 'h2;
        uops[0][37] = 'h1;
        uops[0][36] = 'h1;
        uops[0][35-:32] = 'h25270005;
        uops[0][3-:2] = 'h2;
        uops[0][1] = 'h1;
        uops[0][0] = 'h1;

        uops[1][71-:32] = 'h25270004;
        uops[1][39-:2] = 'h2;
        uops[1][37] = 'h1;
        uops[1][36] = 'h1;
        uops[1][35-:32] = 'h25270005;
        uops[1][3-:2] = 'h2;
        uops[1][1] = 'h1;
        uops[1][0] = 'h1;
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
