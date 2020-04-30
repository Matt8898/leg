module register_file(input  logic  clk,
               input logic reset,
               input  logic        we,
               input  logic [4:0]  ra1, ra2, wa,
               input  logic [31:0] wd,
               output logic [31:0] rd1, rd2
              );

    logic [31:0] rf[31:0];
    logic reg_status[31:0];

    logic [6:0] tags[31:0];

    always @(posedge clk)
    begin
        if(reset) begin
            for(int i = 0; i < 31; i++) begin
                rf[i] = 0;
                if(i == 0) begin
                    rf[i] = 0;
                end
                tags[i] = 0;
            end
        end
        rd1 <= (ra1 != 0) ? rf[ra1] : 0;
        rd2 <= (ra2 != 0) ? rf[ra2] : 0;
    end

    always @(negedge clk) begin
        if (we) rf[wa] <= wd;
    end
endmodule
