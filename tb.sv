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

  logic clkf;

  microcode_exec mc(clk, reset, uops);
/*
  logic [7:0] write_tag_source;
    logic write_tag;
    logic [7:0] read_tag_dest_0;
    logic [7:0] read_tag_dest_1;
    logic read_1_tag;
    logic read_2_tags;

    logic [7:0] freespace;
    logic [7:0] num_items;

    tag_fifo fifo(clk, reset, write_tag_source, write_tag, read_tag_dest_0, read_tag_dest_1, read_1_tag, read_2_tags, freespace, num_items);
 */


  always @(posedge clk) begin
	  /*
	  if(reset) begin
		  write_tag <= 0;
		  read_1_tag <= 0;
		  read_2_tags <= 0;
	  end
	  $display("%x", freespace);
	  if(freespace != 126) begin
		  if(!read_2_tags) begin
			  read_2_tags <= 1;
		  end
	  end
	  if(read_2_tags) begin
		  $display("read: %x %x", read_tag_dest_0, read_tag_dest_1);
		  read_2_tags <= 0;
	  end
	  */
  end
endmodule // test
