module microcode_exec(input wire clk, input wire reset, input logic [31:0] uop_buf [128:0]);
    parameter NUM_PHYS = 128;
    parameter ARCH_REGS = 32;
    parameter ROB_ENTRIES = 128;
    parameter RS_ENTRIES = 128;
    parameter NUM_RS = 7;
    //this is needed since iverilog seems to think the value isn't constant
    //otherwise.
    parameter NUM_RS_LOG2 = $clog2(NUM_RS);

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
    logic [4:0]  reg_addr_1, reg_addr_2, reg_addr_3, reg_addr_4, reg_write_addr;
    logic [31:0] write_source;
    logic [31:0] read_dest_1, read_dest_2, read_dest_3, read_dest_4;
    logic [$clog2(ROB_ENTRIES):0] tags[NUM_PHYS:0];
    logic rbusy[NUM_PHYS:0];

    register_file regs(clk, reset, reg_write, reg_addr_1, reg_addr_2, reg_addr_3, reg_addr_4, reg_write_addr, write_source, read_dest_1, read_dest_2, read_dest_3, read_dest_4);

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
    logic [5:0]  rs_fn [RS_ENTRIES:0][7:0];
    logic [15:0] rs_imm_value[RS_ENTRIES:0][7:0];
    logic [25:0] rs_jump_offset_res[RS_ENTRIES:0][7:0];
    logic [5:0]  rs_rob_entry[RS_ENTRIES:0][7:0];
    logic [$clog2(RS_ENTRIES):0] current_rs_entry[7:0];
    logic [$clog2(RS_ENTRIES):0] next_rs_entry[7:0];

    /*
     * Execution unit
     */
    logic [$clog2(RS_ENTRIES):0] exec_rs_entry[7:0];

    tag_fifo #(NUM_PHYS) fifo (clk, reset, write_tag_source, write_tag, read_tag_dest_0, read_tag_dest_1, read_1_tag, read_2_tags, freespace, num_items);
    always @(posedge clk) begin
      if(reset) begin
        write_tag <= 0;
        read_1_tag <= 0;
        read_2_tags <= 0;
        for(int i = 0; i < RS_ENTRIES; i++) begin
            exec_rs_entry[i] <= 0;
        end
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

            for(int i = 0; i < ARCH_REGS; i++) begin
                current_rat[i] <= 0;
            end

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
    logic is_noop[1:0];

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
    logic is_noop_p[1:0];
    logic split_bundle_p;

    instruction_decoder idec1(fetched_instruction[0],  operation[0],  register_target[0],  register_1[0],  register_2[0],
        jump_offset[0],  sub_field[0],  immediate[0],  rs_station[0],  alu_fn[0],  has_register_1[0],  has_register_2[0],  has_target[0],
        is_noop[0]);
    instruction_decoder idec2(fetched_instruction[1],  operation[1],  register_target[1],  register_1[1],  register_2[1],
        jump_offset[1],  sub_field[1],  immediate[1],  rs_station[1],  alu_fn[1],  has_register_1[1],  has_register_2[1],  has_target[1],
        is_noop[1]);

  pipeline_reg #(120) decode_reg1(clk, reset, !stall, clear_decode_pipeline,
    {operation[0], register_target[0], register_1[0], register_2[0], jump_offset[0], sub_field[0], immediate[0], rs_station[0], alu_fn[0], has_register_1[0], has_register_2[0], has_target[0], fetched_instruction[0], is_noop[0]},
    {operation_p[0], register_target_p[0], register_1_p[0], register_2_p[0], jump_offset_p[0], sub_field_p[0], immediate_p[0],
        rs_station_p[0], alu_fn_p[0], has_register_1_p[0], has_register_2_p[0], has_target_p[0], decoded_instruction[0], is_noop_p[0]});

  pipeline_reg #(121) decode_reg2(clk, reset, !stall, clear_decode_pipeline,
    {operation[1], register_target[1], register_1[1], register_2[1], jump_offset[1], sub_field[1], immediate[1], rs_station[1], alu_fn[1], has_register_1[1], has_register_2[1], has_target[1], fetched_instruction[1], split_bundle, is_noop[1]},
    {operation_p[1], register_target_p[1], register_1_p[1], register_2_p[1], jump_offset_p[1], sub_field_p[1], immediate_p[1],
        rs_station_p[1], alu_fn_p[1], has_register_1_p[1], has_register_2_p[1], has_target_p[1], decoded_instruction[1], split_bundle_p, is_noop_p[1]});

    always_comb begin
        if(rs_station[0] != 0) begin
            split_bundle = rs_station[0] == rs_station[1] /*|| ((has_register_1[1] && has_target[0]) && (register_1[1] == register_target[0] || register_2[1] == register_target[0]))*/;
        end
    end

    /*
     * Pull tags from the physical register fifo.
     */
    always_ff @(posedge clk) begin
        //TODO: if the instruction has no target don't rename
        if(!stall) begin
            if(!split_bundle) begin
                if(!is_noop[1] && !is_noop[0]) begin
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
                if(!is_noop[0]) begin
                    if(num_items >= 2) begin
                        read_2_tags <= 0;
                        read_1_tag <= 1;
                    end else begin
                        read_1_tag <= 0;
                        read_2_tags <= 0;
                        stall_nophys <= 1;
                    end
                end else begin
                    read_1_tag <= 0;
                    read_2_tags <= 0;
                end
            end
        end else begin
            read_1_tag <= 0;
            read_2_tags <= 0;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            reg_addr_1 <= 0;
            reg_addr_2 <= 0;
            reg_addr_3 <= 0;
            reg_addr_4 <= 0;
        end
        if(!stall) begin
            //read register 1 of instruction 1
            //previous bundle wasn't split and the second instruction writes to
            //register_1
            $display("instruction is %x", fetched_instruction[0]);
            if(register_target_p[1] == register_1[0] && !split_bundle_p) begin
                $display("i1: register 1 is written to by instruction 2 of previous bundle");
                reg_addr_1 = read_tag_dest_1;
            end else if(register_target_p[0] == register_1[0]) begin //the first instruction in the previous bundle wrote to this register and the bundle was either split or the second did not write to it.
                $display("i1: register 1 is written to by instruction 1 of previous bundle");
                reg_addr_1 = read_tag_dest_0;
            end else begin
                $display("i1: register 1 is independent of the previous bundle %x %x", register_1[0], current_rat[register_1[0]]);
                reg_addr_1 = current_rat[register_1[0]];
            end

            //read register 2 of instruction 1
            if(register_target_p[1] == register_2[0] && !split_bundle_p) begin
                $display("i1: register 2 is written to by instruction 2 of previous bundle");
                reg_addr_2 = read_tag_dest_1;
            end else if(register_target_p[0] == register_2[0]) begin
                $display("i1: register 2 is written to by instruction 1 of previous bundle");
                reg_addr_2 = read_tag_dest_0;
            end else begin
                $display("i1: register 2 is independent of the previous bundle");
                reg_addr_2 = current_rat[register_2[0]];
            end

            //read register 1 of instruction 2
            //the register is written to by the previous instruction in the bundle
            if(register_target[0] == register_1[1]) begin
                $display("i2: register 1 is written to by instruction 1 of the current bundle");
            end else if(register_target_p[1] == register_1[1] && !split_bundle_p) begin
                $display("i2: register 1 is written to by instruction 2 of previous bundle");
                reg_addr_3 = read_tag_dest_1;
            end else if(register_target_p[1] == register_1[1]) begin
                $display("i2: register 1 is written to by instruction 1 of previous bundle");
                reg_addr_3 = read_tag_dest_0;
            end else begin
                $display("i2: register 1 is independent of the previous bundle");
                reg_addr_3 = current_rat[register_1[1]];
            end

            //read register 2 of instruction 2
            if(register_target[0] == register_2[1]) begin
                $display("i2: register 2 is written to by instruction 1 of the current bundle");
            end else if(register_target_p[1] == register_2[1] && !split_bundle_p) begin
                $display("i2: register 2 is written to by instruction 2 of previous bundle");
                reg_addr_4 = read_tag_dest_1;
            end else if(register_target_p[1] == register_2[1]) begin
                $display("i2: register 2 is written to by instruction 1 of previous bundle");
                reg_addr_4 = read_tag_dest_0;
            end else begin
                $display("i2: register 2 is independent of the previous bundle");
                reg_addr_4 = current_rat[register_2[1]];
            end
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
                if(!is_noop_p[0]) begin
                    $display("instruction 0: %x upc: %x rs station: %x, r1: %x, r2: %x, rt: %x", decoded_instruction[0], upc, rs_station_p[0], register_1_p[0], register_2_p[0], register_target_p[0]);
                    $display("dest renamed to %x", read_tag_dest_0);
                end
                if(!is_noop_p[1] && !split_bundle_p) begin
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

                    if(!is_noop_p[0]) begin
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
                        $display("rs entry: %x", current_rs_entry[rs_station_p[0]]);
                        rs_op_2[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= current_rat[register_2_p[0]];
                        rs_opcode[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= operation_p[0];
                        rs_sub_field_res[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= sub_field_p[0];
                        rs_fn[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= alu_fn_p[0];
                        rs_imm_value[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= immediate_p[0];
                        rs_jump_offset_res[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= jump_offset_p[0];
                        rs_rob_entry[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= current_rob_entry;

                        rs_op_1_busy[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= rbusy[current_rat[register_1_p[0]]];
                        if(!rbusy[current_rat[register_1_p[0]]] && has_register_1_p[0]) begin
                            rs_op_1_tag[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= 0;
                            rs_op_1[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= read_dest_1;
                            $display("operand 1 is available with the value %x", read_dest_1);
                        end else if(has_register_1_p[0]) begin
                            $display("operand 1 is not available %x", rbusy[current_rat[register_1_p[0]]]);
                            rs_op_1_tag[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= tags[current_rat[register_1_p[0]]];
                        end

                        rs_op_2_busy[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= rbusy[current_rat[register_2_p[0]]];
                        if(!rbusy[current_rat[register_1_p[0]]] && has_register_1_p[0]) begin
                            rs_op_2_tag[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= 0;
                            rs_op_1[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= read_dest_2;
                        end else if(has_register_1_p[0]) begin
                            rs_op_2_tag[current_rs_entry[rs_station_p[0]]][rs_station_p[0]] <= tags[current_rat[register_2_p[0]]];
                        end
                    end

                    //Check dependencies between the two issued instructions
                    if(!split_bundle_p && !is_noop_p[1]) begin
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
                        rs_fn[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= alu_fn_p[1];
                        rs_imm_value[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= immediate_p[1];
                        rs_jump_offset_res[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= jump_offset_p[1];
                        rs_rob_entry[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= current_rob_entry;

                        rs_op_1_busy[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= rbusy[current_rat[register_1_p[1]]];
                        if(!rbusy[current_rat[register_1_p[1]]] && has_register_1_p[1]) begin
                            rs_op_1_tag[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= 0;
                            rs_op_1[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= read_dest_3;
                        end else if(has_register_1_p[1]) begin
                            rs_op_1_tag[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= tags[current_rat[register_1_p[1]]];
                        end

                        rs_op_2_busy[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= rbusy[current_rat[register_2_p[1]]];
                        if(!rbusy[current_rat[register_1_p[1]]] && has_register_1_p[1]) begin
                            rs_op_2_tag[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= 0;
                            rs_op_1[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= read_dest_4;
                        end else if(has_register_1_p[1]) begin
                            rs_op_2_tag[current_rs_entry[rs_station_p[1]]][rs_station_p[1]] <= tags[current_rat[register_2_p[1]]];
                        end

                    end else begin
                        if(!is_noop_p[0]) begin
                            if(current_rob_entry == (ROB_ENTRIES - 1)) begin
                                current_rob_entry <= 0;
                            end else begin
                                current_rob_entry <= current_rob_entry + 1;
                            end
                        end
                    end

                    //advance reservation station entry pointers
                    if(!is_noop_p[0]) begin
                        if(current_rs_entry[rs_station_p[0]] == (RS_ENTRIES - 1)) begin
                            current_rs_entry[rs_station_p[0]] <= 0;
                        end else begin
                            current_rs_entry[rs_station_p[0]] <= current_rs_entry[rs_station_p[0]] + 1;
                        end
                    end

                    if(!split_bundle && !is_noop_p[1]) begin
                        if(current_rs_entry[rs_station_p[1]] == (RS_ENTRIES - 1)) begin
                            current_rs_entry[rs_station_p[1]] <= 0;
                        end else begin
                            current_rs_entry[rs_station_p[1]] <= current_rs_entry[rs_station_p[1]] + 1;
                        end
                    end

                    //Rename target register and set register tag
                    if(register_target_p[0] == register_target_p[1] && !split_bundle_p) begin
                        if(!is_noop_p[0]) begin
                            $display("2 instructions have the same target");
                            current_rat[register_target_p[1]] <= read_tag_dest_0;
                            tags[read_tag_dest_0] <= next_rob_entry;
                            rbusy[read_tag_dest_0] <= 1;
                        end
                    end else begin
                        if(!is_noop_p[0]) begin
                            current_rat[register_target_p[0]] <= read_tag_dest_0;
                            tags[read_tag_dest_0] <= current_rob_entry;
                            rbusy[read_tag_dest_0] <= 1;
                        end

                        if(!split_bundle_p && !is_noop_p[1]) begin
                            current_rat[register_target_p[1]] <= read_tag_dest_1;
                            tags[read_tag_dest_1] <= next_rob_entry;
                            rbusy[read_tag_dest_1] <= 1;
                        end
                    end
                end

                if(is_noop_p[0]) begin
                    $display("1: is noop");
                end
                if(is_noop_p[1]) begin
                    $display("2: is noop");
                end

            end
        end
    end

    logic dowork [NUM_RS:0];
    wire w_dowork [NUM_RS:0];
    logic done [NUM_RS:0];
    logic [31:0] result [NUM_RS:0];

    always @(posedge clk) begin
        if(reset) begin
            for(int i = 0; i < NUM_RS; i++) begin
                dowork[i] <= 0;
            end
        end
    end

    assign w_dowork[1] = dowork[1];

    alu_exec alu_exe(clk,
        reset,
        w_dowork[1],
        done[1],
        rs_op_1[exec_rs_entry[1]][1],
        rs_op_2[exec_rs_entry[1]][1],
        rs_fn[exec_rs_entry[1]][1],
        rs_imm_value[exec_rs_entry[1]][1],
        result[1]);

    task execute(input logic [NUM_RS_LOG2:0] number);
        if(rs_busy[exec_rs_entry[number]][number]) begin
            $display("rs is busy");
            //check if the operands are ready
            if(rs_op_1_busy[exec_rs_entry[number]][number] || rs_op_2_busy[exec_rs_entry[number]][number]) begin
                //TODO handle this
            end else begin
                //we can issue the instruction to the execution unit
                if(!dowork[number]) begin
                    $display("execution unit %x can run instruction", number);
                    dowork[number] <= 1;
                end
                if(done[number] && dowork[number]) begin
                    $display("%x done with result %x", number, result[number]);
                    dowork[number] <= 0;
                    rs_busy[exec_rs_entry[number]][number] <= 0;
                end
            end
        end
    endtask

    always @(posedge clk) begin
        execute(1);
    end
endmodule
