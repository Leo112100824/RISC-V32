`include "../../riscv_def.vh"
// 负责控制信号的产生，分给每一个模块，该怎么去操作
module control_unit (
    input  [5:0]       instr_id,
    input  [2:0]       instr_type,
    input  [`XLEN-1:0] instr,

    // ============================================================
    // Write Back
    // ============================================================
    output reg          wb_en,
    output reg [2:0]    reg_wsrc,
    output   [4:0]      rd_addr ,

    // ============================================================
    // ALU
    // ============================================================
    output reg [1:0]    ALUsrc_1,
    output reg [1:0]    ALUsrc_2,
    output reg [3:0]    ALU_op,

    // ============================================================
    // Immediate Generator
    // ============================================================
    output reg [2:0]       control_unit_2_imm_type,
    output reg [`XLEN-1:0] control_unit_2_imm_instr,

    // ============================================================
    // Data Memory / LSU
    // ============================================================
    output reg          mem_rd_en,
    output reg          mem_wr_en,

    // 00 : BYTE
    // 01 : HALF
    // 10 : WORD
    output reg [1:0]    mem_size,

    // Load extension:
    // 0 : signed
    // 1 : unsigned
    //
    // Store 时该信号无意义
    output reg          mem_unsigned,

    // ============================================================
    // Branch Unit
    // ============================================================
    output reg          branch_en,
    output reg [3:0]    branch_type,

    // ============================================================
    // PC control
    //
    // PC_NEXT : PC + 4
    // PC_JAL  : PC + J-imm
    // PC_JALR : (rs1 + I-imm) & ~1
    //
    // 条件 Branch 不在这里直接决定是否跳转。
    // ============================================================
    output reg [1:0]    pc_src
);
assign rd_addr = instr  [11:7];

always @(*) begin

    // ============================================================
    // Default values 所有输出必须先赋默认值，防止 latch。 默认状态表示：   不写寄存器  不访问数据存储器  不发生 branch  PC = PC + 4
    // ------------------------------------------------------------
    // Write Back
    // ------------------------------------------------------------
    wb_en     = 1'b0;
    reg_wsrc  = `WB_ALU;
    // ------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------
    ALUsrc_1 = `ALUSRC1_RS1;
    ALUsrc_2 = `ALUSRC2_RS2;
    ALU_op   = `ALU_ADD;
    // ------------------------------------------------------------
    // Immediate Generator
    // instruction 和 type 直接送给立即数生成器。
    // ------------------------------------------------------------
    control_unit_2_imm_type  = instr_type;
    control_unit_2_imm_instr = instr;
    // ------------------------------------------------------------
    // Data Memory
    // ------------------------------------------------------------
    mem_rd_en    = 1'b0;
    mem_wr_en    = 1'b0;

    mem_size     = `MEM_WORD;
    mem_unsigned = 1'b0;
    // ------------------------------------------------------------
    // Branch
    // ------------------------------------------------------------
    branch_en   = 1'b0;
    branch_type = `BR_BEQ;
    // ------------------------------------------------------------
    // PC
    // ------------------------------------------------------------
    pc_src = `PC_NEXT;
    // ============================================================
    // Instruction Control
    // ============================================================
    case (instr_id)
        `LUI: begin
            wb_en    = 1'b1;
            reg_wsrc = `WB_IMM;
        end
        // --------------------------------------------------------
        // AUIPC
        // rd = PC + U-imm
        // --------------------------------------------------------
        `AUIPC: begin

            ALUsrc_1 = `ALUSRC1_PC;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end

        // ========================================================
        // R TYPE
        // ========================================================
        // --------------------------------------------------------
        // ADD
        // rd = rs1 + rs2
        // --------------------------------------------------------

        `ADD: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_ADD;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end
        // --------------------------------------------------------
        // SUB
        //
        // rd = rs1 - rs2
        // --------------------------------------------------------

        `SUB: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_SUB;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end
        // --------------------------------------------------------
        // SLL
        //
        // rd = rs1 << rs2[4:0]
        // --------------------------------------------------------
        `SLL: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_SLL;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end
        // --------------------------------------------------------
        // SLT
        // signed comparison
        // rd = ($signed(rs1) < $signed(rs2))
        // --------------------------------------------------------

        `SLT: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_SLT;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end

        // --------------------------------------------------------
        // SLTU
        // unsigned comparison
        // --------------------------------------------------------

        `SLTU: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_SLTU   ;

            wb_en    =  1'b1   ;
            reg_wsrc = `WB_ALU ;

        end
        // --------------------------------------------------------
        // XOR
        // --------------------------------------------------------
        `XOR: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_XOR;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end

        // --------------------------------------------------------
        // SRL
        // logical right shift
        // --------------------------------------------------------

        `SRL: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_SRL;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // SRA
        //
        // arithmetic right shift
        // --------------------------------------------------------

        `SRA: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_SRA;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // OR
        // --------------------------------------------------------

        `OR: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_OR;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // AND
        // --------------------------------------------------------

        `AND: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_RS2;
            ALU_op   = `ALU_AND;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end
        // ========================================================
        // I TYPE - ALU
        // ========================================================
        // --------------------------------------------------------
        // ADDI
        //
        // rd = rs1 + I-imm
        // --------------------------------------------------------

        `ADDI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // SLTI
        //
        // signed comparison
        // --------------------------------------------------------

        `SLTI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_SLT;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // SLTIU
        //
        // unsigned comparison
        //
        // 注意：
        // immediate 仍然先进行 sign-extension，
        // 然后进行 unsigned comparison。
        // --------------------------------------------------------

        `SLTIU: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_SLTU;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // XORI
        // --------------------------------------------------------

        `XORI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_XOR;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end
        // --------------------------------------------------------
        // ORI
        // --------------------------------------------------------
        `ORI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_OR;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end

        // --------------------------------------------------------
        // ANDI
        // --------------------------------------------------------

        `ANDI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_AND;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // ========================================================
        // SHIFT IMMEDIATE
        // ========================================================


        // --------------------------------------------------------
        // SLLI
        //
        // rd = rs1 << shamt
        // shamt = instr[24:20]
        // --------------------------------------------------------

        `SLLI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_SLL;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // SRLI
        // --------------------------------------------------------

        `SRLI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_SRL;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // --------------------------------------------------------
        // SRAI
        // --------------------------------------------------------

        `SRAI: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_SRA;

            wb_en    = 1'b1;
            reg_wsrc = `WB_ALU;

        end



        // ========================================================
        // LOAD
        //
        // effective_address = rs1 + I-imm
        //
        // ALU result -> Data Memory address
        // Data Memory -> WB_MEM -> rd
        // ========================================================


        // --------------------------------------------------------
        // LB
        //
        // BYTE + sign extension
        // --------------------------------------------------------

        `LB: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_rd_en    = 1'b1;
            mem_size     = `MEM_BYTE;
            mem_unsigned = 1'b0;

            wb_en    = 1'b1;
            reg_wsrc = `WB_MEM;

        end



        // --------------------------------------------------------
        // LH
        //
        // HALF + sign extension
        // --------------------------------------------------------

        `LH: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_rd_en    = 1'b1;
            mem_size     = `MEM_HALF;
            mem_unsigned = 1'b0;

            wb_en    = 1'b1;
            reg_wsrc = `WB_MEM;

        end



        // --------------------------------------------------------
        // LW
        // --------------------------------------------------------

        `LW: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_rd_en    = 1'b1;
            mem_size     = `MEM_WORD;
            mem_unsigned = 1'b0;

            wb_en    = 1'b1;
            reg_wsrc = `WB_MEM;

        end



        // --------------------------------------------------------
        // LBU
        //
        // BYTE + zero extension
        // --------------------------------------------------------

        `LBU: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_rd_en    = 1'b1;
            mem_size     = `MEM_BYTE;
            mem_unsigned = 1'b1;

            wb_en    = 1'b1;
            reg_wsrc = `WB_MEM;

        end



        // --------------------------------------------------------
        // LHU
        //
        // HALF + zero extension
        // --------------------------------------------------------

        `LHU: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_rd_en    = 1'b1;
            mem_size     = `MEM_HALF;
            mem_unsigned = 1'b1;

            wb_en    = 1'b1;
            reg_wsrc = `WB_MEM;

        end



        // ========================================================
        // STORE
        //
        // effective_address = rs1 + S-imm
        //
        // Memory address = ALU result
        // Memory data    = rs2_data
        // ========================================================


        // --------------------------------------------------------
        // SB
        // --------------------------------------------------------

        `SB: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_wr_en = 1'b1;
            mem_size  = `MEM_BYTE;

        end



        // --------------------------------------------------------
        // SH
        // --------------------------------------------------------

        `SH: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_wr_en = 1'b1;
            mem_size  = `MEM_HALF;

        end



        // --------------------------------------------------------
        // SW
        // --------------------------------------------------------

        `SW: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            mem_wr_en = 1'b1;
            mem_size  = `MEM_WORD;

        end



        // ========================================================
        // BRANCH
        //
        // Control Unit 只告诉 Branch Unit 比较类型。
        //
        // Branch Unit:
        //
        // rs1_data
        //     |
        //     +---- compare ---- branch_taken
        //     |
        // rs2_data
        //
        // target = PC + B-imm
        // ========================================================


        `BEQ: begin

            branch_en   = 1'b1;
            branch_type = `BR_BEQ;

        end



        `BNE: begin

            branch_en   = 1'b1;
            branch_type = `BR_BNE;

        end



        `BLT: begin

            branch_en   = 1'b1;
            branch_type = `BR_BLT;

        end



        `BGE: begin

            branch_en   = 1'b1;
            branch_type = `BR_BGE;

        end



        `BLTU: begin

            branch_en   = 1'b1;
            branch_type = `BR_BLTU;

        end



        `BGEU: begin

            branch_en   = 1'b1;
            branch_type = `BR_BGEU;

        end



        // ========================================================
        // JAL
        //
        // rd      = PC + 4
        // next_pc = PC + J-imm
        // ========================================================

        `JAL: begin

            pc_src = `PC_JAL;

            wb_en    = 1'b1;
            reg_wsrc = `WB_PC4;

        end



        // ========================================================
        // JALR
        //
        // rd      = PC + 4
        //
        // next_pc =
        //
        //     (rs1 + I-imm) & ~1
        //
        // ========================================================

        `JALR: begin

            ALUsrc_1 = `ALUSRC1_RS1;
            ALUsrc_2 = `ALUSRC2_IMM;
            ALU_op   = `ALU_ADD;

            pc_src = `PC_JALR;

            wb_en    = 1'b1;
            reg_wsrc = `WB_PC4;

        end



        // ========================================================
        // Unsupported / Illegal Instruction
        // ========================================================

        default: begin

            // 默认值已经保证：
            //
            // wb_en       = 0
            // mem_rd_en   = 0
            // mem_wr_en   = 0
            // branch_en   = 0
            // pc_src      = PC_NEXT
            //
            // 因此不会产生寄存器/内存副作用。

        end


    endcase
end


endmodule
