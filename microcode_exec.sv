module microcode_exec(input wire clk, input wire reset, input logic [31:0] uop_buf [128:0]);
    parameter NUM_PHYS = 128;
    parameter ARCH_REGS = 32;
    parameter ROB_ENTRIES = 128;
    parameter RS_ENTRIES = 128;

    //general processor control
    logic stall;
    //out of physical registers
    logic stall_nophys;
    //the reorder buffer is full
    logic stall_rob_full;
    //reservation station full
    logic stall_rs_full;
    assign stall = stall_nophys | stall_rob_full | stall_rs_full;

    logic reg_write;
    logic [4:0]  reg_addr_1, reg_addr_2, reg_write_addr;
    logic [31:0] write_source;
    logic [31:0] read_dest_1, read_dest_2;
    logic [$clog2(ROB_ENTRIES):0] tags[NUM_PHYS:0];
    logic rbusy[NUM_PHYS:0];

    register_file regs(clk, reset, reg_write, reg_addr_1, reg_addr_2, reg_write_addr, write_source, read_dest_1, read_dest_2);

    logic reg_busy [ARCH_REGS - 1:0];

    logic split_bundle;
    logic clear_decode_pipeline;

    logic [31:0] upc;
    logic upc_write;
    logic [31:0] upc_write_value;

    logic clear_fetch_pipeline;

    /*
     * physical register queue
     */

    logic [$clog2(NUM_PHYS):0] write_tag_source;
    logic write_tag;
    logic [$clog2(NUM_PHYS):0] read_tag_dest_0;
    logic [$clog2(NUM_PHYS):0] read_tag_dest_1;
    logic read_1_tag;
    logic read_2_tags;

    logic [$clog2(NUM_PHYS):0] freespace;
    logic [$clog2(NUM_PHYS):0] num_items;

    /*
     * Reorder buffer
     */
    logic [5:0] fn [ROB_ENTRIES - 1:0];
    logic [$clog2(NUM_PHYS):0] q_target[ROB_ENTRIES - 1:0];
    logic [$clog2(NUM_PHYS):0] q_op1[ROB_ENTRIES - 1:0];
    logic [$clog2(NUM_PHYS):0] q_op2[ROB_ENTRIES - 1:0];
    logic [$clog2(NUM_PHYS):0] q_op1_arch[ROB_ENTRIES - 1:0];
    logic [$clog2(NUM_PHYS):0] q_op2_arch[ROB_ENTRIES - 1:0];
    logic [15:0] q_immediate[ROB_ENTRIES - 1:0];
    logic [3:0] q_rs_station[ROB_ENTRIES - 1:0];
    logic [31:0] q_result[ROB_ENTRIES - 1:0];
    logic q_ready[ROB_ENTRIES - 1:0];
    logic q_busy[ROB_ENTRIES - 1:0];
    logic [$clog2(ROB_ENTRIES):0] current_rob_entry;
    logic [$clog2(ROB_ENTRIES):0] current_rob_commit;

    /*
     * Reservation stations
     */
    logic        rs_busy [RS_ENTRIES:0][7:0]; //unit n busy
    logic [31:0] rs_op_1[RS_ENTRIES:0][7:0]; //operands
    logic [31:0] rs_op_2[RS_ENTRIES:0][7:0];
    logic [5:0]  rs_op_1_tag[RS_ENTRIES:0][7:0]; //reservation station that will produce this operand
    logic        rs_op_1_busy[RS_ENTRIES:0][7:0];
    logic [5:0]  rs_op_2_tag[RS_ENTRIES:0][7:0];
    logic        rs_op_2_busy[RS_ENTRIES:0][7:0];
    logic [5:0]  rs_opcode[RS_ENTRIES:0][7:0];
    logic [10:0] rs_sub_field_res[RS_ENTRIES:0][7:0];
    logic [15:0] rs_imm_value[RS_ENTRIES:0][7:0];
    logic [25:0] rs_jump_offset_res[RS_ENTRIES:0][7:0];
    logic [5:0]  rs_rob_entry[RS_ENTRIES:0][7:0];
    logic [$clog2(RS_ENTRIES):0] current_rs_entry[7:0];
    logic [$clog2(RS_ENTRIES):0] next_rs_entry[7:0];

    tag_fifo #(NUM_PHYS) fifo (clk, reset, write_tag_source, write_tag, read_tag_dest_0, read_tag_dest_1, read_1_tag, read_2_tags, freespace, num_items);
    always @(posedge clk) begin
      if(reset) begin
        write_tag <= 0;
        read_1_tag <= 0;
        read_2_tags <= 0;
      end
    end

    /*
     * RAT
     */
    //RAT for the currently running state.
    logic [$clog2(NUM_PHYS):0] current_rat[(ARCH_REGS - 1):0];

    always @(posedge clk) begin
        if(reset) begin
            upc <= 0;
            stall_nophys <= 0;
            stall_rob_full <= 0;
            stall_rs_full <= 0;
            upc_write <= 0;
            upc_write_value <= 0;
            split_bundle <= 0;
            clear_fetch_pipeline <= 0;
            current_rob_entry <= 0;

            for(int i = 0; i < ROB_ENTRIES; i++) begin
                q_ready[i] <= 0;
                q_busy[i] <= 0;
            end

            for(int i = 0; i < RS_ENTRIES; i++) begin
                for(int j = 0; j < 7; j++) begin
                    rs_busy[i][j] <= 0;
                end
            end
            for(int i = 0; i < 7; i++) begin
                current_rs_entry[i] <= 0;
            end

            for(int i = 0; i < NUM_PHYS; i++) begin
                tags[i] <= 0;
                rbusy[i] <= 0;
            end
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

    /*
     * Pull tags from the physical register fifo.
     */
    always_ff @(posedge clk) begin
        //TODO: if the instruction has no target don't rename
        if(rs_station[0] != 0 && !stall) begin
            if(!split_bundle) begin
                if(rs_station[1] != 0) begin
                    if(num_items >= 4) begin
                        if(register_target[0] == register_target[1]) begin
                            read_1_tag <= 1;
                            read_2_tags <= 0;
                        end else begin
                            read_2_tags <= 1;
                            read_1_tag <= 0;
                        end
                    end else begin
                        stall_nophys <= 1;
                        read_1_tag <= 0;
                        read_2_tags <= 0;
                    end
                end else begin
                    if(num_items >= 2) begin
                        read_2_tags <= 0;
                        read_1_tag <= 1;
                    end else begin
                        read_1_tag <= 0;
                        read_2_tags <= 0;
                        stall_nophys <= 1;
                    end
                end
            end else begin
                if(num_items >= 2) begin
                    read_2_tags <= 0;
                    read_1_tag <= 1;
                end else begin
                    read_1_tag <= 0;
                    read_2_tags <= 0;
                    stall_nophys <= 1;
                end
            end
        end else begin
            read_1_tag <= 0;
            read_2_tags <= 0;
        end
    end

    //TODO implement stalling for when the issue queues are full.
    logic [$clog2(ROB_ENTRIES):0] next_rob_entry;
    assign next_rob_entry = (current_rob_entry == (ROB_ENTRIES - 1)) ? 0 : (current_rob_entry + 1);

    genvar i;
    generate
        for(i = 0; i < 7; i++) begin
            assign next_rs_entry[i] = (current_rs_entry[i] == (7 - 1) ? 0 : (current_rs_entry[i] + 1));
        end
    endgenerate

    always @(posedge clk) begin
        if(!stall) begin
            if(read_2_tags || read_1_tag) begin
                $display("current_rs_entry: %x %x", current_rs_entry[rs_station_p[0]], rs_busy[current_rs_entry[rs_station_p[0]]][rs_station_p[0]]);
                if(rs_station_p[0] != 0) begin
                    $display("instruction 0: %x upc: %x rs station: %x, r1: %x, r2: %x, rt: %x", decoded_instruction[0], upc, rs_station_p[0], register_1_p[0], register_2_p[0], register_target_p[0]);
                    $display("dest renamed to %x", read_tag_dest_0);
                end
                if(rs_station_p[1] != 0 && !split_bundle_p) begin
                    $display("instruction 1: %x upc: %x rs station: %x, r1: %x, r2: %x, rt: %x", decoded_instruction[1], upc + 1, rs_station_p[1], register_1_p[1], register_2_p[1], register_target_p[1]);
                    $display("dest renamed to %x", read_tag_dest_1);
                end

                if(
                    (split_bundle && (q_busy[current_rob_entry])) || //first rob entry available
                    (!split_bundle && (q_busy[current_rob_entry] || q_busy[next_rob_entry]))//second rob entry available
                ) begin
                    stall_rob_full <= 1;
                end else if(
                    (rs_busy[current_rs_entry[rs_station_p[0]]][rs_station_p[0]]) ||
                    (rs_busy[current_rs_entry[rs_station_p[1]]][rs_station_p[1]])
                ) begin
                    stall_rs_full <= 1;
                    $display("rs full");
                end else begin
                    stall_rob_full <= 0;
                    stall_rs_full <= 0;

                    q_target[current_rob_entry] <= read_tag_dest_0;
                    q_op1[current_rob_entry] <= current_rat[register_1_p[0]];
                    q_op2[current_rob_entry] <= current_rat[register_2_p[0]];
                    q_immediate[current_rob_entry] <= immediate_p[0];
                    q_rs_station[current_rob_entry] <= rs_station_p[0];
                    q_ready[current_rob_entry] <= 0;
                    q_busy[current_rob_entry] <= 1;
                    $display("1: writing to rob entry %x", current_rob_entry);

                    //Enqueue first instruction in the reservation station
                    rs_busy[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= 1;
                    rs_op_1[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= current_rat[register_1_p[0]];
                    rs_op_2[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= current_rat[register_2_p[0]];
                    rs_op_1_busy[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= rbusy[current_rat[register_1_p[0]]];
                    rs_op_2_busy[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= rbusy[current_rat[register_2_p[0]]];
                    rs_op_1_tag[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= tags[current_rat[register_1_p[0]]];
                    rs_op_2_tag[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= tags[current_rat[register_2_p[0]]];
                    rs_opcode[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= operation_p[0];
                    rs_sub_field_res[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= sub_field_p[0];
                    rs_imm_value[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= immediate_p[0];
                    rs_jump_offset_res[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= jump_offset_p[0];
                    rs_rob_entry[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= current_rob_entry;

                    //Check dependencies between the two issued instructions
                    if(!split_bundle_p) begin
                        $display("2: writing to rob entry %x", next_rob_entry);
                        if(register_1_p[1] == register_target_p[0]) begin
                            q_op1[next_rob_entry] <= read_tag_dest_0;
                        end else begin
                            q_op1[next_rob_entry] <= current_rat[register_1_p[1]];
                        end

                        if(register_2_p[1] == register_target_p[0]) begin
                            q_op2[next_rob_entry] <= read_tag_dest_0;
                        end else begin
                            q_op2[next_rob_entry] <= current_rat[register_2_p[1]];
                        end
                        q_target[next_rob_entry] <= read_tag_dest_1;
                        q_immediate[next_rob_entry] <= immediate_p[1];
                        if(current_rob_entry == (ROB_ENTRIES - 1)) begin
                            current_rob_entry <= 1;
                        end else if (current_rob_entry == (ROB_ENTRIES - 2)) begin
                            current_rob_entry <= 0;
                        end else begin
                            current_rob_entry <= current_rob_entry + 2;
                        end

                        rs_busy[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= 1;

                        //Enqueue first instruction in the reservation station
                        rs_busy[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= 1;
                        rs_op_1[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= current_rat[register_1_p[1]];
                        rs_op_2[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= current_rat[register_2_p[1]];
                        rs_op_1_busy[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= rbusy[current_rat[register_1_p[1]]];
                        rs_op_2_busy[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= rbusy[current_rat[register_2_p[1]]];
                        rs_op_1_tag[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= tags[current_rat[register_1_p[1]]];
                        rs_op_2_tag[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= tags[current_rat[register_2_p[1]]];
                        rs_opcode[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= operation_p[1];
                        rs_sub_field_res[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= sub_field_p[1];
                        rs_imm_value[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= immediate_p[1];
                        rs_jump_offset_res[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= jump_offset_p[1];
                        rs_rob_entry[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= current_rob_entry;

                    end else begin
                        if(current_rob_entry == (ROB_ENTRIES - 1)) begin
                            current_rob_entry <= 0;
                        end else begin
                            current_rob_entry <= current_rob_entry + 1;
                        end
                    end

                    //advance reservation station entry pointers
                    if(current_rs_entry[rs_station_p[0]] == (RS_ENTRIES - 1)) begin
                        current_rs_entry[rs_station_p[0]] <= 0;
                    end else begin
                        current_rs_entry[rs_station_p[0]] <= current_rs_entry[rs_station_p[0]] + 1;
                    end

                    if(!split_bundle) begin
                        if(current_rs_entry[rs_station_p[1]] == (RS_ENTRIES - 1)) begin
                            current_rs_entry[rs_station_p[1]] <= 0;
                        end else begin
                            current_rs_entry[rs_station_p[1]] <= current_rs_entry[rs_station_p[1]] + 1;
                        end
                    end

                    //Rename target register and set register tag
                    if(register_target_p[0] == register_target_p[1] && !split_bundle_p) begin
                        $display("2 instructions have the same target");
                        current_rat[register_target_p[1]] <= read_tag_dest_0;
                        tags[read_tag_dest_0] <= next_rob_entry;
                        rbusy[read_tag_dest_0] <= 1;
                    end else begin
                        current_rat[register_target_p[0]] <= read_tag_dest_0;
                        tags[read_tag_dest_0] <= current_rob_entry;
                        tags[read_tag_dest_1] <= next_rob_entry;
                        rbusy[read_tag_dest_0] <= 1;
                        rbusy[read_tag_dest_1] <= 1;

                        if(!split_bundle_p) begin
                            current_rat[register_target_p[1]] <= read_tag_dest_1;
                        end
                    end
                end

            end
        end
    end

    always @(posedge clk) begin
    end
endmodule
