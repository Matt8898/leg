module microcode_exec(input wire clk, input wire reset, input logic [31:0] uop_buf [128:0]);
    //general processor control
    logic stall;

    logic [31:0] upc;
    logic upc_write;
    logic [31:0] upc_write_value;

    always @(posedge clk) begin
        if(reset) begin
            upc <= 0;
            stall <= 0;
            upc_write <= 0;
            upc_write_value <= 0;
        end
        if(!stall) begin
            if(reset) begin
                upc <= 0;
            end else if(upc_write) begin
                upc <= upc_write_value;
                upc_write_value <= 0;
                upc_write <= 0;
            end else begin
                upc <= upc + 1;
            end
        end
    end

    //fetch stage
    logic [31:0] instruction;
    logic [31:0] fetched_instruction;
    assign instruction = uop_buf[upc];

    pipeline_reg #(32) fetch_reg(clk, reset, !stall, clear_fetch_pipeline, instruction, fetched_instruction);

    //decode stage
    logic [5:0] operation;
    logic [4:0] register_target;
    logic [4:0] register_1;
    logic [4:0] register_2;
    logic [25:0] jump_offset;
    logic [10:0] sub_field;
    logic [15:0] immediate;
    logic [3:0]  rs_station;
    logic [5:0]  alu_fn;
    logic has_register_1;
    logic has_register_2;
    logic has_target;
    logic [31:0] decoded_instruction;

    logic instr_type_p;
    logic [5:0] operation_p;
    logic [4:0] register_target_p;
    logic [4:0] register_1_p;
    logic [4:0] register_2_p;
    logic [25:0] jump_offset_p;
    logic [10:0] sub_field_p;
    logic [15:0] immediate_p;
    logic [3:0]  rs_station_p;
    logic [5:0]  alu_fn_p;
    logic has_register_1_p;
    logic has_register_2_p;
    logic has_target_p;

    instruction_decoder idec(fetched_instruction, operation, register_target, register_1, register_2, jump_offset, sub_field, immediate, rs_station, alu_fn, has_register_1, has_register_2, has_target);
    pipeline_reg #(119) decode_reg(clk, reset, !stall, clear_decode_pipeline,
        {operation, register_target, register_1, register_2, jump_offset, sub_field, immediate, rs_station, alu_fn, has_register_1, has_register_2, has_target, fetched_instruction},
        {operation_p, register_target_p, register_1_p, register_2_p, jump_offset_p, sub_field_p, immediate_p, rs_station_p, alu_fn_p, has_register_1_p, has_register_2_p, has_target_p, decoded_instruction});


    logic out_of_tags;
    logic [8:0] current_phys_reg;
    rat r(clk, reset, out_of_tags);

    always @(posedge clk) begin
//        r.get_tag(current_phys_reg);
//        $display("Current tag: %x, out: %x", current_phys_reg, out_of_tags);
        if(rs_station_p != 0) begin
            $display("upc: %x rs station: %x, r1: %x, r2: %x, rt: %x", upc, rs_station_p, register_1_p, register_2_p, register_target_p);
        end
    end
endmodule
