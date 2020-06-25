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
/*
   always @(posedge clk) begin
       if(reset) begin
           done <= 0;
           result <= 0;
           working <= 0;
        end
        if(done) begin
            done <= 0;
        end
       if(dowork && !working && !done) begin
           $display("dowork is true");
           done <= 0;
           result <= 0;
           counter <= 0;
           working <= 1;
        end

        if(working) begin
            counter <= counter + 1;
            if(counter == 3) begin
                working <= 0;
                done <= 1;
                result <= 1;
                counter <= 0;
            end
        end
   end*/
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
        done <= 1;
		if(fn == 0) begin
        	result <= 1;
		end
    end
   end

endmodule
