module tag_fifo(
    input logic clk,
    input logic reset,

    input logic [7:0] write_tag_source,
    input logic write_tag,
    output logic [7:0] read_tag_dest_0,
    output logic [7:0] read_tag_dest_1,
    input logic read_1_tag,
    input logic read_2_tags,

    output logic [7:0] freespace
);

logic [7:0] write_ptr;
logic [7:0] read_ptr;

logic [7:0] data[127:0];

assign freespace = (write_ptr > read_ptr) ? (127 - write_ptr + read_ptr) : (read_ptr - write_ptr);

always @(posedge clk) begin
    if(reset) begin
        for(int i = 0; i < 127; i++) begin
            data[i] <= i;
        end
        write_ptr <= 127;
        read_ptr <= 0;
    end
    if(read_1_tag) begin
        assert(freespace >= 1);
        $display("read %x", data[read_ptr]);
        read_tag_dest_0 <= data[read_ptr];
        if(read_ptr != 127) begin
            read_ptr <= read_ptr + 1;
        end else begin
            read_ptr <= 0;
        end
    end
    if(read_2_tags) begin
        assert(freespace >= 2);
        $display("read 1 %x", data[read_ptr]);
        read_tag_dest_0 <= data[read_ptr];
        if(read_ptr != 126) begin
            read_tag_dest_1 <= data[read_ptr + 1];
            $display("read 2 %x", data[read_ptr + 1]);
            read_ptr <= read_ptr + 2;
        end else begin
            if(read_ptr == 126) begin
                $display("read 2 %x", data[0]);
                read_tag_dest_1 <= data[0];
                read_ptr <= 1;
            end else begin
                $display("read 2 %x", data[read_ptr + 1]);
                read_tag_dest_1 <= data[read_ptr + 1];
                read_ptr <= 0;
            end
        end
    end

    if(write_tag) begin
        if(write_ptr != 127) begin
            write_ptr <= write_ptr + 1;
        end else begin
            write_ptr <= 0;
        end
        $display("write %x", write_tag_source);
        data[write_ptr] <= write_tag_source;
    end
end

endmodule
