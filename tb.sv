module test;
    parameter UOP_BUF_SIZE = 128;
    parameter UOP_BUF_WIDTH = 64;
    logic [(UOP_BUF_WIDTH - 1):0] uops[0:(UOP_BUF_SIZE - 1)];

    initial
    begin
        $dumpfile("test.vcd");
        $dumpvars(0, mc);
        $readmemh("memfile.dat", uops);
    end


    /* Make a reset that pulses once. */
    logic reset = 0;
    initial begin
        # 0 reset = 1;
        # 1 reset = 0;
        # 2 reset = 1;
        # 3 reset = 0;
    end

    logic clk = 0;
    logic [31:0] cnt;
    always #5 clk = !clk;
    logic [$clog2(UOP_BUF_SIZE) - 1:0] uop_addr;
    logic [(UOP_BUF_WIDTH - 1):0] uop;

    assign uop = uops[uop_addr];
    microcode_unit #(UOP_BUF_SIZE, UOP_BUF_WIDTH) mc(.clk(clk), .reset(reset), .uop_addr(uop_addr), .uop(uop));
endmodule
