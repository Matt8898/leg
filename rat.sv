/*
 * register allocation table + free tag stack
 */
interface rat(input logic clk, input logic reset, output logic out_of_tags);
    /*
     * tag stack logic
     */
    logic phys_regs[200:0];
    logic [8:0] idx;

    always @(posedge clk) begin
        if(reset) begin
            out_of_tags <= 0;
            for(int i = 0; i < 200; i++) begin
                phys_regs[i] <= 0;
            end
            for(int i = 0; i < 8; i++) begin
                idx <= 0;
            end
        end
    end

    task get_tag(output logic [8:0] out_idx);
    begin
        if(phys_regs[idx + 1] == 0) begin
            idx <= idx + 1;
            phys_regs[idx] <= 1;
            out_idx <= idx;
            out_of_tags <= 0;
        end else begin
            out_of_tags <= 1;
        end
    end
    endtask

    task unset_tag(input logic [8:0] i);
    begin
        phys_regs[i] <= 0;
    end
    endtask

    /*
     * rat logic
     */
    //mapping of architectural registers to physical registers.
    logic [8:0] mappings [16:0];
    logic busy[16:0];
endinterface
