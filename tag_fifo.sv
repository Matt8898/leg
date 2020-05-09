module tag_fifo(
    input logic clk,
    input logic reset,

    input logic [$clog2(WIDTH):0] write_tag_source,
    input logic write_tag,
    output logic [$clog2(WIDTH):0] read_tag_dest_0,
    output logic [$clog2(WIDTH):0] read_tag_dest_1,
    input logic read_1_tag,
    input logic read_2_tags,

    output logic [$clog2(WIDTH):0] freespace,
    output logic [$clog2(WIDTH):0] num_items
);

logic [$clog2(WIDTH):0] write_ptr;
logic [$clog2(WIDTH):0] read_ptr;

parameter WIDTH = 128;

logic [$clog2(WIDTH):0] data[WIDTH - 1:0];

assign num_items = (write_ptr > read_ptr) ? (write_ptr - read_ptr) : (write_ptr - read_ptr + WIDTH);
assign freespace = WIDTH - num_items;

assign read_tag_dest_0 = data[read_ptr];
assign read_tag_dest_1 = data[(read_ptr == (WIDTH - 1)) ? (0) : (read_ptr + 1)];

always @(posedge clk) begin
    if(reset) begin
        for(int i = 0; i <= WIDTH; i++) begin
            data[i] <= i;
        end
        write_ptr <= WIDTH - 1;
        read_ptr <= 0;
    end
    if(read_1_tag) begin
        assert(num_items >= 1);
        if(read_ptr != (WIDTH - 1)) begin
            read_ptr <= read_ptr + 1;
        end else begin
            read_ptr <= 0;
        end
    end else if(read_2_tags) begin
       assert(num_items >= 2);
       if(read_ptr == (WIDTH - 1)) begin
            read_ptr <= 1;
        end else if(read_ptr == (WIDTH - 2)) begin
            read_ptr <= 0;
        end else begin
            read_ptr <= read_ptr + 2;
        end
    end

    if(write_tag) begin
        if(write_ptr != (WIDTH - 1)) begin
            write_ptr <= write_ptr + 1;
        end else begin
            write_ptr <= 0;
        end
        $display("write %x", write_tag_source);
        data[write_ptr] <= write_tag_source;
    end
end

endmodule
