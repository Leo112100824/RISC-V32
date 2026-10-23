`include "../../riscv_def.vh"

// ============================================================================
//  decoder
//
//  合并原 decode.v（指令识别）与 control_unit.v（控制信号生成）。
//  一个组合逻辑模块同时输出：
//    - 指令字段（rs1/rs2/rd）
//    - 操作数使用信息（给 hazard unit）
//    - 立即数（内部实例化 imm_gen）
//    - 全部数据通路控制信号
//
//  设计原则：
//    1. 先识别 instruction_id，再由 instruction_id 生成控制，保持原有两级
//       译码的可读性，但收敛到同一个模块内。
//    2. 所有输出先赋默认值，杜绝 latch。
//    3. 未实现但已识别的 SYSTEM / FENCE 指令置 system_instr，不产生副作用，
//       等阶段三 trap 单元接入后再形成真实行为。
// ============================================================================
module decoder (
    input  wire [31:0] instr,

    // ------------------------------------------------------------------
    // Instruction fields
    // ------------------------------------------------------------------
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    output wire [4:0]  rd_addr,

    // 给 hazard unit：该指令是否真的读 rs1 / rs2
    output reg         rs1_used,
    output reg         rs2_used,

    // ------------------------------------------------------------------
    // Immediate
    // ------------------------------------------------------------------
    output wire [31:0] imm,

    // ------------------------------------------------------------------
    // Decode status
    // ------------------------------------------------------------------
    output reg         illegal,
    output wire        system_instr,

    // ------------------------------------------------------------------
    // Write back
    // ------------------------------------------------------------------
    output reg         wb_en,
    output reg  [2:0]  wb_src,

    // ------------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------------
    output reg  [1:0]  alu_src1,
    output reg  [1:0]  alu_src2,
    output reg  [3:0]  alu_op,

    // ------------------------------------------------------------------
    // Data memory
    // ------------------------------------------------------------------
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  mem_size,
    output reg         mem_unsigned,

    // ------------------------------------------------------------------
    // Branch / jump
    // ------------------------------------------------------------------
    output reg         branch,
    output reg  [3:0]  branch_type,
    output reg  [1:0]  pc_src,

    // ------------------------------------------------------------------
    // Instruction class flags (hazard / forwarding / debug)
    // ------------------------------------------------------------------
    output wire        is_load,
    output wire        is_store,
    output wire        is_branch,
    output wire        is_jal,
    output wire        is_jalr
);

    // ========================================================================
    // Instruction fields
    // ========================================================================
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr  = instr[11:7];

    // ========================================================================
    // Internal decode result
    // ========================================================================
    reg  [5:0] instr_id;
    reg  [2:0] instr_type;

    // ========================================================================
    // Immediate generation
    // ========================================================================
    imm_gen u_imm_gen (
        .instruction      (instr),
        .instruction_type (instr_type),
        .immediate        (imm)
    );

    // ========================================================================
    // Stage 1: instruction identification
    // ========================================================================
    always @(*) begin
        instr_id   = `INST_INVALID;
        instr_type = `NONE_TYPE;
        rs1_used   = 1'b0;
        rs2_used   = 1'b0;

        case (opcode)
            // ------------------------------------------------------------------
            // LUI / AUIPC
            // ------------------------------------------------------------------
            `OPCODE_LUI: begin
                instr_id   = `LUI;
                instr_type = `U_TYPE;
            end

            `OPCODE_AUIPC: begin
                instr_id   = `AUIPC;
                instr_type = `U_TYPE;
            end

            // ------------------------------------------------------------------
            // JAL / JALR
            // ------------------------------------------------------------------
            `OPCODE_JAL: begin
                instr_id   = `JAL;
                instr_type = `J_TYPE;
            end

            `OPCODE_JALR: begin
                if (funct3 == `F3_JALR) begin
                    instr_id   = `JALR;
                    instr_type = `I_TYPE;
                    rs1_used   = 1'b1;
                end
            end

            // ------------------------------------------------------------------
            // BRANCH
            // ------------------------------------------------------------------
            `OPCODE_BRANCH: begin
                instr_type = `B_TYPE;
                rs1_used   = 1'b1;
                rs2_used   = 1'b1;

                case (funct3)
                    `F3_BEQ:  instr_id = `BEQ;
                    `F3_BNE:  instr_id = `BNE;
                    `F3_BLT:  instr_id = `BLT;
                    `F3_BGE:  instr_id = `BGE;
                    `F3_BLTU: instr_id = `BLTU;
                    `F3_BGEU: instr_id = `BGEU;
                    default:  instr_id = `INST_INVALID;
                endcase
            end

            // ------------------------------------------------------------------
            // LOAD
            // ------------------------------------------------------------------
            `OPCODE_LOAD: begin
                instr_type = `I_TYPE;
                rs1_used   = 1'b1;

                case (funct3)
                    `F3_LB:  instr_id = `LB;
                    `F3_LH:  instr_id = `LH;
                    `F3_LW:  instr_id = `LW;
                    `F3_LBU: instr_id = `LBU;
                    `F3_LHU: instr_id = `LHU;
                    default: instr_id = `INST_INVALID;
                endcase
            end

            // ------------------------------------------------------------------
            // STORE
            // ------------------------------------------------------------------
            `OPCODE_STORE: begin
                instr_type = `S_TYPE;
                rs1_used   = 1'b1;
                rs2_used   = 1'b1;

                case (funct3)
                    `F3_SB: instr_id = `SB;
                    `F3_SH: instr_id = `SH;
                    `F3_SW: instr_id = `SW;
                    default: instr_id = `INST_INVALID;
                endcase
            end

            // ------------------------------------------------------------------
            // OP-IMM
            // ------------------------------------------------------------------
            `OPCODE_OP_IMM: begin
                instr_type = `I_TYPE;
                rs1_used   = 1'b1;

                case (funct3)
                    `F3_ADD_SUB: instr_id = `ADDI;
                    `F3_SLT:     instr_id = `SLTI;
                    `F3_SLTU:    instr_id = `SLTIU;
                    `F3_XOR:     instr_id = `XORI;
                    `F3_OR:      instr_id = `ORI;
                    `F3_AND:     instr_id = `ANDI;

                    `F3_SLL: begin
                        if (funct7 == `FUNCT7_NORMAL)
                            instr_id = `SLLI;
                    end

                    `F3_SRL_SRA: begin
                        case (funct7)
                            `FUNCT7_NORMAL:    instr_id = `SRLI;
                            `FUNCT7_SUB_SRA:   instr_id = `SRAI;
                            default:           instr_id = `INST_INVALID;
                        endcase
                    end

                    default: instr_id = `INST_INVALID;
                endcase
            end

            // ------------------------------------------------------------------
            // OP
            // ------------------------------------------------------------------
            `OPCODE_OP: begin
                instr_type = `R_TYPE;
                rs1_used   = 1'b1;
                rs2_used   = 1'b1;

                case (funct3)
                    `F3_ADD_SUB: begin
                        case (funct7)
                            `FUNCT7_NORMAL:  instr_id = `ADD;
                            `FUNCT7_SUB_SRA: instr_id = `SUB;
                            default:         instr_id = `INST_INVALID;
                        endcase
                    end

                    `F3_SLL: begin
                        if (funct7 == `FUNCT7_NORMAL) instr_id = `SLL;
                    end

                    `F3_SLT: begin
                        if (funct7 == `FUNCT7_NORMAL) instr_id = `SLT;
                    end

                    `F3_SLTU: begin
                        if (funct7 == `FUNCT7_NORMAL) instr_id = `SLTU;
                    end

                    `F3_XOR: begin
                        if (funct7 == `FUNCT7_NORMAL) instr_id = `XOR;
                    end

                    `F3_SRL_SRA: begin
                        case (funct7)
                            `FUNCT7_NORMAL:  instr_id = `SRL;
                            `FUNCT7_SUB_SRA: instr_id = `SRA;
                            default:         instr_id = `INST_INVALID;
                        endcase
                    end

                    `F3_OR: begin
                        if (funct7 == `FUNCT7_NORMAL) instr_id = `OR;
                    end

                    `F3_AND: begin
                        if (funct7 == `FUNCT7_NORMAL) instr_id = `AND;
                    end

                    default: instr_id = `INST_INVALID;
                endcase
            end

            // ------------------------------------------------------------------
            // MISC-MEM: FENCE / FENCE.I
            // 已识别，但当前没有内存序/指令流同步行为，按无副作用处理。
            // ------------------------------------------------------------------
            `OPCODE_MISC_MEM: begin
                case (funct3)
                    `F3_FENCE:  instr_id = `FENCE;
                    `F3_FENCEI: instr_id = `FENCEI;
                    default:    instr_id = `INST_INVALID;
                endcase
            end

            // ------------------------------------------------------------------
            // SYSTEM: ECALL / EBREAK / CSR
            // 已识别，等 trap / csr_file 接入后形成真实行为。
            // ------------------------------------------------------------------
            `OPCODE_SYSTEM: begin
                if (instr == 32'h0000_0073) begin
                    instr_id = `ECALL;
                end else if (instr == 32'h0010_0073) begin
                    instr_id = `EBREAK;
                end else begin
                    case (funct3)
                        `F3_CSRRW: begin
                            instr_id   = `CSRRW;
                            instr_type = `I_TYPE;      // 源为 rs1，不使用立即数
                            rs1_used   = 1'b1;
                        end
                        `F3_CSRRS: begin
                            instr_id   = `CSRRS;
                            instr_type = `I_TYPE;
                            rs1_used   = 1'b1;
                        end
                        `F3_CSRRC: begin
                            instr_id   = `CSRRC;
                            instr_type = `I_TYPE;
                            rs1_used   = 1'b1;
                        end
                        `F3_CSRRWI: begin
                            instr_id   = `CSRRWI;
                            instr_type = `CSR_TYPE;    // 源为 zimm
                        end
                        `F3_CSRRSI: begin
                            instr_id   = `CSRRSI;
                            instr_type = `CSR_TYPE;
                        end
                        `F3_CSRRCI: begin
                            instr_id   = `CSRRCI;
                            instr_type = `CSR_TYPE;
                        end
                        default: instr_id = `INST_INVALID;
                    endcase
                end
            end

            default: instr_id = `INST_INVALID;
        endcase

        // 非法编码必须完全无副作用
        illegal = (instr_id == `INST_INVALID);
        if (illegal) begin
            instr_type = `NONE_TYPE;
            rs1_used   = 1'b0;
            rs2_used   = 1'b0;
        end
    end

    // ========================================================================
    // Stage 2: control generation
    // ========================================================================
    always @(*) begin
        // ------------------------------------------------------------------
        // Defaults: 不写回、不访存、不分支、PC+4、ALU 用 rs1/rs2
        // ------------------------------------------------------------------
        wb_en        = 1'b0;
        wb_src       = `WB_ALU;
        alu_src1     = `ALUSRC1_RS1;
        alu_src2     = `ALUSRC2_RS2;
        alu_op       = `ALU_ADD;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_size     = `MEM_WORD;
        mem_unsigned = 1'b0;
        branch       = 1'b0;
        branch_type  = `BR_BEQ;
        pc_src       = `PC_NEXT;

        case (instr_id)
            // ------------------------------------------------------------------
            // R-type
            // ------------------------------------------------------------------
            `ADD, `SUB, `SLL, `SLT, `SLTU, `XOR, `SRL, `SRA, `OR, `AND: begin
                wb_en    = 1'b1;
                wb_src   = `WB_ALU;
                alu_src1 = `ALUSRC1_RS1;
                alu_src2 = `ALUSRC2_RS2;

                case (instr_id)
                    `ADD:  alu_op = `ALU_ADD;
                    `SUB:  alu_op = `ALU_SUB;
                    `SLL:  alu_op = `ALU_SLL;
                    `SLT:  alu_op = `ALU_SLT;
                    `SLTU: alu_op = `ALU_SLTU;
                    `XOR:  alu_op = `ALU_XOR;
                    `SRL:  alu_op = `ALU_SRL;
                    `SRA:  alu_op = `ALU_SRA;
                    `OR:   alu_op = `ALU_OR;
                    `AND:  alu_op = `ALU_AND;
                endcase
            end

            // ------------------------------------------------------------------
            // I-type arithmetic
            // ------------------------------------------------------------------
            `ADDI, `SLTI, `SLTIU, `XORI, `ORI, `ANDI, `SLLI, `SRLI, `SRAI: begin
                wb_en    = 1'b1;
                wb_src   = `WB_ALU;
                alu_src1 = `ALUSRC1_RS1;
                alu_src2 = `ALUSRC2_IMM;

                case (instr_id)
                    `ADDI:  alu_op = `ALU_ADD;
                    `SLTI:  alu_op = `ALU_SLT;
                    `SLTIU: alu_op = `ALU_SLTU;
                    `XORI:  alu_op = `ALU_XOR;
                    `ORI:   alu_op = `ALU_OR;
                    `ANDI:  alu_op = `ALU_AND;
                    `SLLI:  alu_op = `ALU_SLL;
                    `SRLI:  alu_op = `ALU_SRL;
                    `SRAI:  alu_op = `ALU_SRA;
                endcase
            end

            // ------------------------------------------------------------------
            // Loads
            // ------------------------------------------------------------------
            `LB, `LH, `LW, `LBU, `LHU: begin
                wb_en    = 1'b1;
                wb_src   = `WB_MEM;
                alu_src1 = `ALUSRC1_RS1;
                alu_src2 = `ALUSRC2_IMM;
                alu_op   = `ALU_ADD;
                mem_read = 1'b1;

                case (instr_id)
                    `LB:  begin mem_size = `MEM_BYTE; mem_unsigned = `MEM_SIGNED;   end
                    `LH:  begin mem_size = `MEM_HALF; mem_unsigned = `MEM_SIGNED;   end
                    `LW:  begin mem_size = `MEM_WORD; mem_unsigned = `MEM_SIGNED;   end
                    `LBU: begin mem_size = `MEM_BYTE; mem_unsigned = `MEM_UNSIGNED; end
                    `LHU: begin mem_size = `MEM_HALF; mem_unsigned = `MEM_UNSIGNED; end
                endcase
            end

            // ------------------------------------------------------------------
            // Stores
            // ------------------------------------------------------------------
            `SB, `SH, `SW: begin
                alu_src1  = `ALUSRC1_RS1;
                alu_src2  = `ALUSRC2_IMM;
                alu_op    = `ALU_ADD;
                mem_write = 1'b1;

                case (instr_id)
                    `SB: mem_size = `MEM_BYTE;
                    `SH: mem_size = `MEM_HALF;
                    `SW: mem_size = `MEM_WORD;
                endcase
            end

            // ------------------------------------------------------------------
            // Branches
            // ------------------------------------------------------------------
            `BEQ, `BNE, `BLT, `BGE, `BLTU, `BGEU: begin
                branch = 1'b1;

                case (instr_id)
                    `BEQ:  branch_type = `BR_BEQ;
                    `BNE:  branch_type = `BR_BNE;
                    `BLT:  branch_type = `BR_BLT;
                    `BGE:  branch_type = `BR_BGE;
                    `BLTU: branch_type = `BR_BLTU;
                    `BGEU: branch_type = `BR_BGEU;
                endcase
            end

            // ------------------------------------------------------------------
            // JAL
            // ------------------------------------------------------------------
            `JAL: begin
                pc_src = `PC_JAL;
                wb_en  = 1'b1;
                wb_src = `WB_PC4;
            end

            // ------------------------------------------------------------------
            // JALR
            // ------------------------------------------------------------------
            `JALR: begin
                alu_src1 = `ALUSRC1_RS1;
                alu_src2 = `ALUSRC2_IMM;
                alu_op   = `ALU_ADD;
                pc_src   = `PC_JALR;
                wb_en    = 1'b1;
                wb_src   = `WB_PC4;
            end

            // ------------------------------------------------------------------
            // LUI / AUIPC
            // ------------------------------------------------------------------
            `LUI: begin
                wb_en  = 1'b1;
                wb_src = `WB_IMM;
            end

            `AUIPC: begin
                alu_src1 = `ALUSRC1_PC;
                alu_src2 = `ALUSRC2_IMM;
                alu_op   = `ALU_ADD;
                wb_en    = 1'b1;
                wb_src   = `WB_ALU;
            end

            // ------------------------------------------------------------------
            // FENCE / SYSTEM / 非法：保持默认值（无副作用）
            // ------------------------------------------------------------------
            default: ;
        endcase
    end

    // ========================================================================
    // Instruction class flags
    // ========================================================================
    assign is_load   = (instr_id == `LB) || (instr_id == `LH) || (instr_id == `LW) ||
                       (instr_id == `LBU) || (instr_id == `LHU);
    assign is_store  = (instr_id == `SB) || (instr_id == `SH) || (instr_id == `SW);
    assign is_branch = (instr_id == `BEQ) || (instr_id == `BNE) || (instr_id == `BLT) ||
                       (instr_id == `BGE) || (instr_id == `BLTU) || (instr_id == `BGEU);
    assign is_jal    = (instr_id == `JAL);
    assign is_jalr   = (instr_id == `JALR);

    assign system_instr = (instr_id == `FENCE)  || (instr_id == `FENCEI) ||
                          (instr_id == `ECALL)  || (instr_id == `EBREAK) ||
                          (instr_id == `CSRRW)  || (instr_id == `CSRRS)  ||
                          (instr_id == `CSRRC)  || (instr_id == `CSRRWI) ||
                          (instr_id == `CSRRSI) || (instr_id == `CSRRCI);

endmodule
