#include "instruction.sv"
#include "defines.inc"

module instruction_decoder (
    input fetched_instruction instruction,
    output decoded_instruction decoded
);

logic [31:0] op;

assign op = instruction.instruction;

always_comb begin
    decoded.operation = op[31:26];
    decoded.alu_fn = op[5:0];
    decoded.branch_tag = instruction.branch_tag;
    decoded.macroop_start = instruction.macroop_start;
    decoded.macroop_end = instruction.macroop_end;
    decoded.reg_reg_mov = 0;
    case(op[31:26])
        6'b001001://addiu
        begin
            decoded.rs_station = 1;
            decoded.register_1 = op[25:21];
            decoded.register_2 = 0;
            decoded.register_target = op[20:16];
            decoded.immediate = op[15:0];
            decoded.has_reg1 = 1;
            decoded.has_reg2 = 0;
            decoded.has_target = 1;
            decoded.alu_fn = 0;
        end
        6'b001100://andi
        begin
            decoded.rs_station = 1;
            decoded.rs_station = 1;
            decoded.register_1 = op[25:21];
            decoded.register_2 = 0;
            decoded.register_target = op[20:16];
            decoded.immediate = op[15:0];
            decoded.has_reg1 = 1;
            decoded.has_reg2 = 0;
            decoded.has_target = 1;
            decoded.alu_fn = 2;
        end
        6'b000100:
        begin
            decoded.rs_station = 3;
            decoded.has_reg1 = 1;
            decoded.register_1 = op[25:21];
            decoded.has_reg2 = 1;
            decoded.register_2 = op[20:16];
            decoded.has_target = 0;
            decoded.immediate = op[15:0];
            decoded.alu_fn = 3;
        end
        6'b100011://lw
        begin
            decoded.rs_station = 4;
            decoded.has_reg1 = 1;
            decoded.register_1 = op[25:21];
            decoded.has_target = 1;
            decoded.register_target = op[20:16];
            decoded.immediate = op[15:0];
            decoded.alu_fn = 0;//load word
        end
        6'b101011://lw
        begin
            decoded.rs_station = 4;
            decoded.has_reg1 = 1;
            decoded.register_1 = op[25:21];
            decoded.has_reg2 = 1;
            decoded.register_2 = op[20:16];
            decoded.immediate = op[15:0];
            decoded.alu_fn = 1;//load word
        end
        6'b001111: begin //lui
            decoded.rs_station = 3;
            decoded.register_1 = 0;
            decoded.register_2 = 0;
            decoded.register_target = op[20:16];
            decoded.immediate = op[15:0];
            decoded.has_reg1 = 0;
            decoded.has_reg2 = 0;
            decoded.has_target = 1;
            decoded.alu_fn = 0;
        end
        6'b0:
        begin
            case (decoded.alu_fn)
                6'b100001: begin
                   decoded.register_target = op[15:11];
                   decoded.rs_station = 1;
                   decoded.register_1 = op[25:21];
                   decoded.has_reg1 = 1;
                   decoded.register_2 = op[20:16];
                   decoded.has_reg2 = 1;
                   decoded.immediate = 0;
                   decoded.has_target = 1;
                   decoded.alu_fn = 0;
                   $display("addiu: %x %x %x %x", decoded.register_1, decoded.register_2, decoded.register_target, (decoded.register_1 == 0 || decoded.register_2 == 0) && (decoded.register_target != 0));
                   decoded.reg_reg_mov = (decoded.register_1 == 0 || decoded.register_2 == 0) && (decoded.register_target != 0);
                end
                6'b100100: begin
                   decoded.register_target = op[15:11];
                   decoded.rs_station = 1;
                   decoded.register_1 = op[25:21];
                   decoded.has_reg1 = 1;
                   decoded.register_2 = op[20:16];
                   decoded.has_reg2 = 1;
                   decoded.immediate = 0;
                   decoded.has_target = 1;
                   decoded.alu_fn = 1;
                end
                6'b011010: begin
                   decoded.rs_station = 2;
                   decoded.register_1 = op[25:21];
                   decoded.has_reg1 = 1;
                   decoded.register_2 = op[20:16];
                   decoded.has_reg2 = 1;
                   decoded.immediate = 0;
                   decoded.has_target = 1;
                   decoded.alu_fn = 0;
                end
                6'b010000: begin
                   decoded.rs_station = 2;
                   decoded.has_reg1 = 0;
                   decoded.has_reg2 = 0;
                   decoded.register_1 = 0;
                   decoded.register_2 = 0;
                   decoded.register_target = op[15:11];
                   decoded.immediate = 0;
                   decoded.has_target = 1;
                   decoded.alu_fn = 1;
                end
                6'b010010: begin
                   decoded.rs_station = 2;
                   decoded.has_reg1 = 0;
                   decoded.has_reg2 = 0;
                   decoded.register_1 = 0;
                   decoded.register_2 = 0;
                   decoded.register_target = op[15:11];
                   decoded.immediate = 0;
                   decoded.has_target = 1;
                   decoded.alu_fn = 2;
                end
               default: begin
                    decoded.rs_station = 0;
                    decoded.has_reg1 = 0;
                    decoded.has_reg2 = 0;
                    decoded.has_target = 0;
                end
            endcase
        end
    default:
        begin
            decoded.rs_station = 0;
//            $display("unknown instruction: %x", op);
        end
    endcase

    if(decoded.rs_station == 0 || (decoded.register_target == 0 && decoded.has_target)) begin
        decoded.is_noop = 1;
    end else begin
        decoded.is_noop = 0;
    end
    decoded.is_zerocycle = decoded.is_noop | decoded.reg_reg_mov;
end
endmodule
