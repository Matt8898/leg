module alu_exec(input logic clk,
    input logic reset,
    input wire dowork,
    output logic done,
    input logic [31:0] op_1,
    input logic [31:0] op_2,
    input logic [5:0] fn,
    input logic [15:0] immediate,
    output logic [31:0] result
   );

   logic [3:0] counter;
   logic working;

   always @(posedge clk) begin
       if(reset) begin
           done <= 0;
           result <= 0;
           working <= 0;
        end
    if(done) begin
        done <= 0;
    end
    if(dowork && !done) begin
        $display("operands: %x %x", op_1, op_2);
        done <= 1;
        if(fn == 0) begin
            result <= op_1 + op_2 + immediate;
        end
    end
   end

endmodule
