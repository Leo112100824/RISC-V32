`include "../../riscv_def.vh"

module instr_decoder (
    input  wire [31:0] instr,
    // 立即数类型
    output reg  [2:0]  imm_type,
    //传递给ALu 
    output reg  [3:0]  alu_op,
    output reg         alu_src_b,
    //寄存器堆的读写 
    output reg         reg_write,
    output reg  [1:0]  wb_sel,
    //存储读取 
    output reg         mem_read,
    output reg  [2:0]  mem_write_size,
    // 分支信号
    output reg         branch,
    output reg  [2:0]  branch_cond,
    output reg         jal,
    output reg         jalr,
    // 加载数据
    output reg         lui,
    output reg         auipc,
    // CSR寄存器
    output reg         csr_op,
    output reg  [1:0]  csr_write_mode,
    output reg         ecall,
    output reg         ebreak,
    output reg         mret,
    output reg         wfi,
    output reg         fence,
    //非法命令   
    output reg         illegal_instr
);

    // ALU operation encoding (shared with alu).
    localparam [3:0] ALU_ADD    = 4'b0000;
    localparam [3:0] ALU_SUB    = 4'b0001;
    localparam [3:0] ALU_SLL    = 4'b0010;
    localparam [3:0] ALU_SLT    = 4'b0011;
    localparam [3:0] ALU_SLTU   = 4'b0100;
    localparam [3:0] ALU_XOR    = 4'b0101;
    localparam [3:0] ALU_SRL    = 4'b0110;
    localparam [3:0] ALU_SRA    = 4'b0111;
    localparam [3:0] ALU_OR     = 4'b1000;
    localparam [3:0] ALU_AND    = 4'b1001;
    localparam [3:0] ALU_PASS_B = 4'b1010;

    // Write-back source: ALU, load data, or PC+4.
    localparam [1:0] WB_ALU = 2'd0;
    localparam [1:0] WB_MEM = 2'd1;
    localparam [1:0] WB_PC4 = 2'd2;

    // branch_cond follows funct3 for the six RV32 branch predicates.
    localparam [2:0] BR_BEQ  = 3'b000;
    localparam [2:0] BR_BNE  = 3'b001;
    localparam [2:0] BR_BLT  = 3'b100;
    localparam [2:0] BR_BGE  = 3'b101;
    localparam [2:0] BR_BLTU = 3'b110;
    localparam [2:0] BR_BGEU = 3'b111;

    // csr_write_mode encodes the operation class.  Whether the source is
    // rs1 or zimm remains visible in instr[14:12] to the CSR stage.
    localparam [1:0] CSR_WRITE = 2'd0;
    localparam [1:0] CSR_SET   = 2'd1;
    localparam [1:0] CSR_CLEAR = 2'd2;

    always @(*) begin
        // Safe defaults for bubbles and illegal instructions.
        imm_type       = `I_TYPE;
        alu_op         = ALU_ADD;
        alu_src_b      = 1'b0;
        reg_write      = 1'b0;
        wb_sel         = WB_ALU;
        mem_read       = 1'b0;
        mem_write_size = 3'd0;
        branch         = 1'b0;
        branch_cond    = BR_BEQ;
        jal            = 1'b0;
        jalr           = 1'b0;
        lui            = 1'b0;
        auipc          = 1'b0;
        csr_op         = 1'b0;
        csr_write_mode = CSR_WRITE;
        ecall          = 1'b0;
        ebreak         = 1'b0;
        mret           = 1'b0;
        wfi            = 1'b0;
        fence          = 1'b0;
        illegal_instr  = 1'b0;

        case (instr[6:0])
            7'b0110111: begin // LUI
                imm_type  = `U_TYPE;
                alu_op    = ALU_PASS_B;
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                lui       = 1'b1;
            end

            7'b0010111: begin // AUIPC
                imm_type  = `U_TYPE;
                alu_op    = ALU_ADD;
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                auipc     = 1'b1;
            end

            7'b1101111: begin // JAL
                imm_type  = `J_TYPE;
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                wb_sel    = WB_PC4;
                jal       = 1'b1;
            end

            7'b1100111: begin // JALR
                if (instr[14:12] == 3'b000) begin
                    imm_type  = `I_TYPE;
                    alu_op    = ALU_ADD;
                    alu_src_b = 1'b1;
                    reg_write = 1'b1;
                    wb_sel    = WB_PC4;
                    jalr      = 1'b1;
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            7'b1100011: begin // conditional branches
                if ((instr[14:12] == BR_BEQ)  ||
                    (instr[14:12] == BR_BNE)  ||
                    (instr[14:12] == BR_BLT)  ||
                    (instr[14:12] == BR_BGE)  ||
                    (instr[14:12] == BR_BLTU) ||
                    (instr[14:12] == BR_BGEU)) begin
                    imm_type    = `B_TYPE;
                    alu_op      = ALU_SUB;
                    branch      = 1'b1;
                    branch_cond = instr[14:12];
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            7'b0000011: begin // loads: LB/LH/LW/LBU/LHU
                imm_type  = `I_TYPE;
                alu_op    = ALU_ADD;
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                wb_sel    = WB_MEM;
                case (instr[14:12])
                    3'b000, 3'b100: mem_write_size = 3'd0; // byte
                    3'b001, 3'b101: mem_write_size = 3'd1; // half-word
                    3'b010:         mem_write_size = 3'd2; // word
                    default: begin
                        mem_write_size = 3'd0;
                        reg_write      = 1'b0;
                        wb_sel         = WB_ALU;
                        illegal_instr  = 1'b1;
                    end
                endcase
                if (!illegal_instr)
                    mem_read = 1'b1;
            end

            7'b0100011: begin // stores: SB/SH/SW
                imm_type  = `S_TYPE;
                alu_op    = ALU_ADD;
                alu_src_b = 1'b1;
                case (instr[14:12])
                    3'b000: mem_write_size = 3'd0; // byte
                    3'b001: mem_write_size = 3'd1; // half-word
                    3'b010: mem_write_size = 3'd2; // word
                    default: illegal_instr = 1'b1;
                endcase
            end

            7'b0010011: begin // OP-IMM
                imm_type  = `I_TYPE;
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                case (instr[14:12])
                    3'b000: alu_op = ALU_ADD;  // ADDI
                    3'b010: alu_op = ALU_SLT;  // SLTI
                    3'b011: alu_op = ALU_SLTU; // SLTIU
                    3'b100: alu_op = ALU_XOR;  // XORI
                    3'b110: alu_op = ALU_OR;   // ORI
                    3'b111: alu_op = ALU_AND;  // ANDI
                    3'b001: begin               // SLLI, funct7=0000000
                        if (instr[31:25] == 7'b0000000)
                            alu_op = ALU_SLL;
                        else
                            illegal_instr = 1'b1;
                    end
                    3'b101: begin               // SRLI/SRAI
                        if (instr[31:25] == 7'b0000000)
                            alu_op = ALU_SRL;
                        else if (instr[31:25] == 7'b0100000)
                            alu_op = ALU_SRA;
                        else
                            illegal_instr = 1'b1;
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            7'b0110011: begin // OP (RV32I only; M is added in stage four)
                reg_write = 1'b1;
                case (instr[14:12])
                    3'b000: begin
                        if (instr[31:25] == 7'b0000000)
                            alu_op = ALU_ADD;
                        else if (instr[31:25] == 7'b0100000)
                            alu_op = ALU_SUB;
                        else
                            illegal_instr = 1'b1; // includes M/MUL
                    end
                    3'b001: begin
                        if (instr[31:25] == 7'b0000000) alu_op = ALU_SLL;
                        else illegal_instr = 1'b1;
                    end
                    3'b010: begin
                        if (instr[31:25] == 7'b0000000) alu_op = ALU_SLT;
                        else illegal_instr = 1'b1;
                    end
                    3'b011: begin
                        if (instr[31:25] == 7'b0000000) alu_op = ALU_SLTU;
                        else illegal_instr = 1'b1;
                    end
                    3'b100: begin
                        if (instr[31:25] == 7'b0000000) alu_op = ALU_XOR;
                        else illegal_instr = 1'b1;
                    end
                    3'b101: begin
                        if (instr[31:25] == 7'b0000000)
                            alu_op = ALU_SRL;
                        else if (instr[31:25] == 7'b0100000)
                            alu_op = ALU_SRA;
                        else
                            illegal_instr = 1'b1;
                    end
                    3'b110: begin
                        if (instr[31:25] == 7'b0000000) alu_op = ALU_OR;
                        else illegal_instr = 1'b1;
                    end
                    3'b111: begin
                        if (instr[31:25] == 7'b0000000) alu_op = ALU_AND;
                        else illegal_instr = 1'b1;
                    end
                    default: illegal_instr = 1'b1;
                endcase
                if (illegal_instr)
                    reg_write = 1'b0;
            end

            7'b0001111: begin // FENCE/FENCE.I (ordering handled later)
                if ((instr[14:12] == 3'b000) ||
                    (instr[14:12] == 3'b001))
                    fence = 1'b1;
                else
                    illegal_instr = 1'b1;
            end

            7'b1110011: begin // SYSTEM: CSR and machine environment ops
                case (instr[14:12])
                    3'b000: begin
                        // ECALL, EBREAK, MRET and WFI have fixed encodings.
                        if (instr[31:20] == 12'h000 &&
                            instr[19:15] == 5'd0 && instr[11:7] == 5'd0)
                            ecall = 1'b1;
                        else if (instr[31:20] == 12'h001 &&
                                 instr[19:15] == 5'd0 && instr[11:7] == 5'd0)
                            ebreak = 1'b1;
                        else if (instr[31:20] == 12'h302 &&
                                 instr[19:15] == 5'd0 && instr[11:7] == 5'd0)
                            mret = 1'b1;
                        else if (instr[31:20] == 12'h105 &&
                                 instr[19:15] == 5'd0 && instr[11:7] == 5'd0)
                            wfi = 1'b1;
                        else
                            illegal_instr = 1'b1;
                    end
                    3'b001, 3'b101: begin // CSRRW / CSRRWI
                        csr_op         = 1'b1;
                        csr_write_mode = CSR_WRITE;
                        reg_write      = 1'b1;
                    end
                    3'b010, 3'b110: begin // CSRRS / CSRRSI
                        csr_op         = 1'b1;
                        csr_write_mode = CSR_SET;
                        reg_write      = 1'b1;
                    end
                    3'b011, 3'b111: begin // CSRRC / CSRRCI
                        csr_op         = 1'b1;
                        csr_write_mode = CSR_CLEAR;
                        reg_write      = 1'b1;
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            default: illegal_instr = 1'b1;
        endcase

        // An illegal encoding must be architecturally inert.  Keep the
        // diagnostic bit asserted, but remove every possible side effect in
        // case a later stage does not independently gate on illegal_instr.
        if (illegal_instr) begin
            alu_src_b      = 1'b0;
            reg_write      = 1'b0;
            wb_sel         = WB_ALU;
            mem_read       = 1'b0;
            mem_write_size = 3'd0;
            branch         = 1'b0;
            jal            = 1'b0;
            jalr           = 1'b0;
            lui            = 1'b0;
            auipc          = 1'b0;
            csr_op         = 1'b0;
            ecall          = 1'b0;
            ebreak         = 1'b0;
            mret           = 1'b0;
            wfi            = 1'b0;
            fence          = 1'b0;
        end
    end

endmodule
