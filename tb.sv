module test;

    logic [31:0] uops[128:0];

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

  /* Make a regular pulsing clock. */
  logic clk = 0;
  always #5 clk = !clk;

  microcode_exec mc(clk, reset, uops);
endmodule // test
