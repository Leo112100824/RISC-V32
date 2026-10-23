`include "../../riscv_def.vh"

module decode (
    input              [`XLEN-1:0]      instr                      ,


    output reg         [   5:0]         instruction_id             ,
    output reg         [   2:0]         instruction_type           ,

    // 用于后面的 hazard unit
    output reg                          rs1_used                   ,
    output reg                          rs2_used                   ,

    output                              illegal_instr               
);

// ============================================================================
// Instruction Fields
// ============================================================================

wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;

assign opcode = instr[6:0];
assign funct3 = instr[14:12];
assign funct7 = instr[31:25];

// ============================================================================
// 非法指令检测
// ============================================================================

assign illegal_instr = (instruction_id == `INST_INVALID);

always @(*) begin

    // -----------初值------

    instruction_id   = `INST_INVALID;
    instruction_type = `NONE_TYPE;
    rs1_used = 1'b0;
    rs2_used = 1'b0;
    case (opcode)
        // ====================================================================
        // LUI
        // ====================================================================
        `OPCODE_LUI: begin
            instruction_id   = `LUI;
            instruction_type = `U_TYPE;
        end
        // ====================================================================
        // AUIPC
        // ====================================================================
        `OPCODE_AUIPC: begin
            instruction_id   = `AUIPC;
            instruction_type = `U_TYPE;
        end
        // ====================================================================
        // JAL
        // ====================================================================
        `OPCODE_JAL: begin
            instruction_id   = `JAL;
            instruction_type = `J_TYPE;
        end
        // ====================================================================
        // JALR
        // ====================================================================
        `OPCODE_JALR: begin
            if (funct3 == `F3_JALR) begin
                instruction_id   = `JALR;
                instruction_type = `I_TYPE;
                rs1_used = 1'b1;
            end
        end
        // ====================================================================
        // BRANCH
        // ====================================================================
        `OPCODE_BRANCH: begin
            instruction_type = `B_TYPE;
            rs1_used = 1'b1;
            rs2_used = 1'b1;
            case (funct3)
                `F3_BEQ:
                    instruction_id = `BEQ;
                `F3_BNE:
                    instruction_id = `BNE;
                `F3_BLT:
                    instruction_id = `BLT;
                `F3_BGE:
                    instruction_id = `BGE;
                `F3_BLTU:
                    instruction_id = `BLTU;
                `F3_BGEU:
                    instruction_id = `BGEU;

                default:
                    instruction_id = `INST_INVALID;
            endcase
        end
        // ====================================================================
        // LOAD
        // ====================================================================
        `OPCODE_LOAD: begin
            instruction_type = `I_TYPE;
            rs1_used = 1'b1;
            case (funct3)
                `F3_LB:
                    instruction_id = `LB;
                `F3_LH:
                    instruction_id = `LH;
                `F3_LW:
                    instruction_id = `LW;
                `F3_LBU:
                    instruction_id = `LBU;
                `F3_LHU:
                    instruction_id = `LHU;
                default:
                    instruction_id = `INST_INVALID;
            endcase
        end
        // ====================================================================
        // STORE
        // ====================================================================
        `OPCODE_STORE: begin
            instruction_type = `S_TYPE;
            rs1_used = 1'b1;
            rs2_used = 1'b1;
            case (funct3)
                `F3_SB:
                    instruction_id = `SB;
                `F3_SH:
                    instruction_id = `SH;
                `F3_SW:
                    instruction_id = `SW;
                default:
                    instruction_id = `INST_INVALID;
            endcase
        end
        // ====================================================================
        // OP-IMM
        //
        // ADDI / SLTI / SLTIU / XORI / ORI / ANDI
        // SLLI / SRLI / SRAI
        // ====================================================================
        `OPCODE_OP_IMM: begin
            instruction_type = `I_TYPE;
            rs1_used = 1'b1;
            case (funct3)
                `F3_ADD_SUB: begin
                    instruction_id = `ADDI;
                end
                `F3_SLT: begin
                    instruction_id = `SLTI;
                end
                `F3_SLTU: begin
                    instruction_id = `SLTIU;
                end
                `F3_XOR: begin
                    instruction_id = `XORI;
                end
                `F3_OR: begin
                    instruction_id = `ORI;
                end
                `F3_AND: begin
                    instruction_id = `ANDI;
                end
                // ------------------------------------------------------------
                // SLLI
                // ------------------------------------------------------------
                `F3_SLL: begin
                    if (funct7 == `FUNCT7_NORMAL)
                        instruction_id = `SLLI;
                    else
                        instruction_id = `INST_INVALID;
                end
                // ------------------------------------------------------------
                // SRLI / SRAI
                // ------------------------------------------------------------
                `F3_SRL_SRA: begin
                    case (funct7)
                        `FUNCT7_NORMAL:
                            instruction_id = `SRLI;
                        `FUNCT7_SUB_SRA:
                            instruction_id = `SRAI;
                        default:
                            instruction_id = `INST_INVALID;
                    endcase
                end
                default: begin

                    instruction_id = `INST_INVALID;

                end

            endcase

        end
        // ====================================================================
        // OP
        // ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND
        // ====================================================================
        `OPCODE_OP: begin
            instruction_type = `R_TYPE;
            rs1_used = 1'b1;
            rs2_used = 1'b1;
            case (funct3)
                // ------------------------------------------------------------
                // ADD / SUB
                // ------------------------------------------------------------
                `F3_ADD_SUB: begin
                    case (funct7)
                        `FUNCT7_NORMAL:
                            instruction_id = `ADD;
                        `FUNCT7_SUB_SRA:
                            instruction_id = `SUB;
                        default:
                            instruction_id = `INST_INVALID;
                    endcase

                end


                // ------------------------------------------------------------
                // SLL
                // ------------------------------------------------------------

                `F3_SLL: begin

                    if (funct7 == `FUNCT7_NORMAL)
                        instruction_id = `SLL;
                    else
                        instruction_id = `INST_INVALID;

                end


                // ------------------------------------------------------------
                // SLT
                // ------------------------------------------------------------

                `F3_SLT: begin

                    if (funct7 == `FUNCT7_NORMAL)
                        instruction_id = `SLT;
                    else
                        instruction_id = `INST_INVALID;

                end


                // ------------------------------------------------------------
                // SLTU
                // ------------------------------------------------------------

                `F3_SLTU: begin

                    if (funct7 == `FUNCT7_NORMAL)
                        instruction_id = `SLTU;
                    else
                        instruction_id = `INST_INVALID;

                end


                // ------------------------------------------------------------
                // XOR
                // ------------------------------------------------------------

                `F3_XOR: begin

                    if (funct7 == `FUNCT7_NORMAL)
                        instruction_id = `XOR;
                    else
                        instruction_id = `INST_INVALID;

                end


                // ------------------------------------------------------------
                // SRL / SRA
                // ------------------------------------------------------------

                `F3_SRL_SRA: begin
                    case (funct7)
                        `FUNCT7_NORMAL:
                            instruction_id = `SRL;
                        `FUNCT7_SUB_SRA:
                            instruction_id = `SRA;
                        default:
                            instruction_id = `INST_INVALID;
                    endcase

                end


                // ------------------------------------------------------------
                // OR
                // ------------------------------------------------------------

                `F3_OR: begin

                    if (funct7 == `FUNCT7_NORMAL)
                        instruction_id = `OR;
                    else
                        instruction_id = `INST_INVALID;
                end
                // ------------------------------------------------------------
                // AND
                // ------------------------------------------------------------

                `F3_AND: begin

                    if (funct7 == `FUNCT7_NORMAL)
                        instruction_id = `AND;
                    else
                        instruction_id = `INST_INVALID;

                end


                default: begin

                    instruction_id = `INST_INVALID;
                end
            endcase
        end
        // ====================================================================
        // FENCE / FENCE.I
        // ====================================================================
        `OPCODE_MISC_MEM: begin
            case (funct3)
                `F3_FENCE:
                    instruction_id = `FENCE;
                `F3_FENCEI:
                    instruction_id = `FENCEI;
                default:
                    instruction_id = `INST_INVALID;
            endcase
        end
        // ====================================================================
        // SYSTEM / CSR
        // ====================================================================
        `OPCODE_SYSTEM: begin
            // ----------------------------------------------------------------
            // ECALL
            // ----------------------------------------------------------------
            if (instr == 32'h0000_0073) begin
                instruction_id = `ECALL;
            end
            // ----------------------------------------------------------------
            // EBREAK
            // ----------------------------------------------------------------
            else if (instr == 32'h0010_0073) begin
                instruction_id = `EBREAK;
            end
            // ----------------------------------------------------------------
            // CSR
            // ----------------------------------------------------------------
            else begin
                case (funct3)
                    // --------------------------------------------------------
                    // Register CSR
                    // --------------------------------------------------------
                    `F3_CSRRW: begin
                        instruction_id = `CSRRW;
                        rs1_used = 1'b1;
                    end
                    `F3_CSRRS: begin
                        instruction_id = `CSRRS;
                        rs1_used = 1'b1;
                    end
                    `F3_CSRRC: begin
                        instruction_id = `CSRRC;
                        rs1_used = 1'b1;
                    end
                    // --------------------------------------------------------
                    // Immediate CSR
                    // --------------------------------------------------------
                    `F3_CSRRWI: begin
                        instruction_id   = `CSRRWI;
                        instruction_type = `CSR_TYPE;
                    end
                    `F3_CSRRSI: begin
                        instruction_id   = `CSRRSI;
                        instruction_type = `CSR_TYPE;
                    end
                    `F3_CSRRCI: begin
                        instruction_id   = `CSRRCI;
                        instruction_type = `CSR_TYPE;
                    end
                    default:  instruction_id = `INST_INVALID;     
                endcase
            end
        end
        // ====================================================================
        // Unknown Opcode
        // ====================================================================

        default:  instruction_id = `INST_INVALID;

    endcase

    // =========================================================================
    // instruction_type / used 信号全部清零。
    // =========================================================================

    if (instruction_id == `INST_INVALID) begin

        instruction_type = `NONE_TYPE;

        rs1_used = 1'b0;
        rs2_used = 1'b0;

    end

end

endmodule
