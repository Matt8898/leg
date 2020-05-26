module instruction_decoder(
    input logic [31:0] op,
    output logic [5:0] operation,
    output logic [4:0] register_target,
    output logic [4:0] register_1,
    output logic [4:0] register_2,
    output logic [25:0] jump_offset,
    output logic [10:0] sub_field,
    output logic [15:0] immediate,
    output logic [3:0]  rs_station,
    output logic [5:0] alu_fn,
    output logic has_register_1,
    output logic has_register_2,
    output logic has_target,
	output logic is_noop
);


always_comb begin
    operation = op[31:26];
    alu_fn = op[5:0];
    case(operation)
        6'b001001://addiu
        begin
            rs_station = 1;
            register_1 = op[25:21];
            register_2 = 0;
            register_target = op[20:16];
            immediate = op[15:0];
            has_register_1 = 1;
            has_register_2 = 0;
            has_target = 1;
            alu_fn = 0;
        end
        6'b001100://andi
        begin
            rs_station = 1;
            rs_station = 1;
            register_1 = op[25:21];
            register_2 = 0;
            register_target = op[20:16];
            immediate = op[15:0];
            has_register_1 = 1;
            has_register_2 = 0;
            has_target = 1;
            alu_fn = 2;
        end
        6'b000100:
        begin
            rs_station = 3;
            has_register_1 = 1;
            register_1 = op[25:21];
            has_register_2 = 1;
            register_2 = op[20:16];
            has_target = 0;
            immediate = op[15:0];
            alu_fn = 3;
        end
        6'b100011://lw
        begin
            rs_station = 4;
            has_register_1 = 1;
            register_1 = op[25:21];
            has_target = 1;
            register_target = op[20:16];
            immediate = op[15:0];
            alu_fn = 0;//load word
        end
        6'b101011://lw
        begin
            rs_station = 4;
            has_register_1 = 1;
            register_1 = op[25:21];
            has_register_2 = 1;
            register_2 = op[20:16];
            immediate = op[15:0];
            alu_fn = 1;//load word
        end
        6'b001111: begin //lui
            rs_station = 3;
            register_1 = 0;
            register_2 = 0;
            register_target = op[20:16];
            immediate = op[15:0];
            has_register_1 = 0;
            has_register_2 = 0;
            has_target = 1;
            alu_fn = 0;
        end
        6'b0:
        begin
            case (alu_fn)
                6'b100001: begin
                   register_target = op[15:11];
                   rs_station = 1;
                   register_1 = op[25:21];
                   has_register_1 = 1;
                   register_2 = op[20:16];
                   has_register_2 = 1;
                   immediate = 0;
                   has_target = 1;
                   alu_fn = 0;
                end
                6'b100100: begin
                   register_target = op[15:11];
                   rs_station = 1;
                   register_1 = op[25:21];
                   has_register_1 = 1;
                   register_2 = op[20:16];
                   has_register_2 = 1;
                   immediate = 0;
                   has_target = 1;
                   alu_fn = 1;
                end
                6'b011010: begin
                   rs_station = 2;
                   register_1 = op[25:21];
                   has_register_1 = 1;
                   register_2 = op[20:16];
                   has_register_2 = 1;
                   immediate = 0;
                   has_target = 1;
                   alu_fn = 0;
                end
                6'b010000: begin
                   rs_station = 2;
                   has_register_1 = 0;
                   has_register_2 = 0;
                   register_1 = 0;
                   register_2 = 0;
                   register_target = op[15:11];
                   immediate = 0;
                   has_target = 1;
                   alu_fn = 1;
                end
                6'b010010: begin
                   rs_station = 2;
                   has_register_1 = 0;
                   has_register_2 = 0;
                   register_1 = 0;
                   register_2 = 0;
                   register_target = op[15:11];
                   immediate = 0;
                   has_target = 1;
                   alu_fn = 2;
                end
               default: begin
                    rs_station = 0;
                    has_register_1 = 0;
                    has_register_2 = 0;
                    has_target = 0;
                end
            endcase
        end
    default:
        begin
            rs_station = 0;
//            $display("unknown instruction: %x", op);
        end
    endcase

	if(rs_station == 0 || (register_target == 0 && has_target)) begin
		is_noop = 1;
	end else begin
		is_noop = 0;
	end
end
endmodule
