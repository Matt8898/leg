module microcode_exec(input wire clk, input wire reset, input logic [31:0] uop_buf [128:0]);
    //general processor control
    logic stall;
    logic split_bundle;
    logic clear_decode_pipeline;

    logic [31:0] upc;
    logic upc_write;
    logic [31:0] upc_write_value;

    logic clear_fetch_pipeline;

    always @(posedge clk) begin
        if(reset) begin
            upc <= 0;
            stall <= 0;
            upc_write <= 0;
            upc_write_value <= 0;
            split_bundle <= 0;
            clear_fetch_pipeline <= 0;
        end
        if(!stall) begin
            if(reset) begin
                upc <= 0;
            end else if(upc_write) begin
                upc <= upc_write_value;
                upc_write_value <= 0;
                upc_write <= 0;
            end else begin
                if(split_bundle) begin
                    $display("split");
                    upc <= upc - 1;
                    split_bundle <= 0;
                end else begin
                    upc <= upc + 2;
                end
            end
        end
    end

    //fetch stage
    logic [31:0] instruction[2:0];
    logic [31:0] fetched_instruction[1:0];

    always @(posedge clk) begin
        if(!clear_fetch_pipeline) begin
            if(!split_bundle) begin
                fetched_instruction[0] <= uop_buf[upc];
                fetched_instruction[1] <= uop_buf[upc + 1];
            end else begin
                fetched_instruction[0] <= 0;
                fetched_instruction[1] <= 0;
            end
        end else begin
            fetched_instruction[0] <= 0;
            fetched_instruction[1] <= 0;
            clear_fetch_pipeline <= 0;
        end


        if(instruction[0] != 0)
            $display("instrs: %x %x", instruction[0], instruction[1]);
    end


//    pipeline_reg #(32) fetch_reg1(clk, reset, !stall, clear_fetch_pipeline, instruction[0], fetched_instruction[0]);
//    pipeline_reg #(32) fetch_reg2(clk, reset, !stall, clear_fetch_pipeline, instruction[1], fetched_instruction[1]);

    //decode stage
    logic [5:0] operation[1:0];
    logic [4:0] register_target[1:0];
    logic [4:0] register_1[1:0];
    logic [4:0] register_2[1:0];
    logic [25:0] jump_offset[1:0];
    logic [10:0] sub_field[1:0];
    logic [15:0] immediate[1:0];
    logic [3:0]  rs_station[1:0];
    logic [5:0]  alu_fn[1:0];
    logic has_register_1[1:0];
    logic has_register_2[1:0];
    logic has_target[1:0];
    logic [31:0] decoded_instruction[1:0];

    logic instr_type_p[1:0];
    logic [5:0] operation_p[1:0];
    logic [4:0] register_target_p[1:0];
    logic [4:0] register_1_p[1:0];
    logic [4:0] register_2_p[1:0];
    logic [25:0] jump_offset_p[1:0];
    logic [10:0] sub_field_p[1:0];
    logic [15:0] immediate_p[1:0];
    logic [3:0]  rs_station_p[1:0];
    logic [5:0]  alu_fn_p[1:0];
    logic has_register_1_p[1:0];
    logic has_register_2_p[1:0];
    logic has_target_p[1:0];
    logic split_bundle_p;

    instruction_decoder idec1(fetched_instruction[0],  operation[0],  register_target[0],  register_1[0],  register_2[0],
        jump_offset[0],  sub_field[0],  immediate[0],  rs_station[0],  alu_fn[0],  has_register_1[0],  has_register_2[0],  has_target[0]);
    instruction_decoder idec2(fetched_instruction[1],  operation[1],  register_target[1],  register_1[1],  register_2[1],
        jump_offset[1],  sub_field[1],  immediate[1],  rs_station[1],  alu_fn[1],  has_register_1[1],  has_register_2[1],  has_target[1]);

  pipeline_reg #(119) decode_reg1(clk, reset, !stall, clear_decode_pipeline,
    {operation[0], register_target[0], register_1[0], register_2[0], jump_offset[0], sub_field[0], immediate[0], rs_station[0], alu_fn[0], has_register_1[0], has_register_2[0], has_target[0], fetched_instruction[0]},
    {operation_p[0], register_target_p[0], register_1_p[0], register_2_p[0], jump_offset_p[0], sub_field_p[0], immediate_p[0],
        rs_station_p[0], alu_fn_p[0], has_register_1_p[0], has_register_2_p[0], has_target_p[0], decoded_instruction[0]});

  pipeline_reg #(120) decode_reg2(clk, reset, !stall, clear_decode_pipeline,
    {operation[1], register_target[1], register_1[1], register_2[1], jump_offset[1], sub_field[1], immediate[1], rs_station[1], alu_fn[1], has_register_1[1], has_register_2[1], has_target[1], fetched_instruction[1], split_bundle},
    {operation_p[1], register_target_p[1], register_1_p[1], register_2_p[1], jump_offset_p[1], sub_field_p[1], immediate_p[1],
        rs_station_p[1], alu_fn_p[1], has_register_1_p[1], has_register_2_p[1], has_target_p[1], decoded_instruction[1], split_bundle_p});

    always_comb begin
        if(rs_station[0] != 0) begin
            split_bundle = rs_station[0] == rs_station[1];
        end
    end

    logic out_of_tags;
    logic [8:0] current_phys_reg;
    rat r(clk, reset, out_of_tags);

    always @(posedge clk) begin
        if(rs_station_p[0] != 0) begin
            $display("instruction 0: %x upc: %x rs station: %x, r1: %x, r2: %x, rt: %x", decoded_instruction[0], upc, rs_station_p[0], register_1_p[0], register_2_p[0], register_target_p[0]);
        end
        if(rs_station_p[1] != 0 && !split_bundle_p) begin
            $display("instruction 1: %x upc: %x rs station: %x, r1: %x, r2: %x, rt: %x", decoded_instruction[1], upc + 1, rs_station_p[1], register_1_p[1], register_2_p[1], register_target_p[1]);
        end
    end
endmodule
