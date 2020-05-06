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
  logic [31:0] cnt;
  always #5 clk = !clk;

  microcode_exec mc(clk, reset, uops);

    logic [7:0] write_tag_source;
    logic write_tag;
    logic [7:0] read_tag_dest_0;
    logic [7:0] read_tag_dest_1;
    logic read_1_tag;
    logic read_2_tags;

    logic [7:0] freespace;

  tag_fifo fifo(clk, reset, write_tag_source, write_tag, read_tag_dest_0, read_tag_dest_1, read_1_tag, read_2_tags, freespace);

  always @(posedge clk) begin
	  if(freespace != 126) begin
		  if(read_1_tag) begin
			  $display("tag read: %x", read_tag_dest_0);
			  read_1_tag <= 0;
		  end else begin
			  read_1_tag <= 1;
		  end
	  end else begin
		  write_tag <= 1;
		  write_tag_source <= 5;
	  end
	  if(write_tag) begin
		  write_tag <= 0;
	  end
  end
endmodule // test
