`include "../../riscv_def.vh"

// ============================================================================
//  id_stage
//
//  流水线第 3 级：译码 + 读寄存器 + 生成控制/立即数，并在末尾包含
//  ID/EX 流水线寄存器。
//
//  - decoder  : decode + control + imm 的合并版本
//  - regfile  : 32x32，x0 恒 0，写优先旁路
//  - ID/EX reg: 本模块内部，下一级 EX 只看到已寄存的信号
//
//  stall：向 EX 插入 bubble（valid=0），IF2 中的指令保持不变。
//  flush：分支/跳转/异常重定向，清除 ID/EX。
// ============================================================================
module id_stage (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        stall,
    input  wire        flush,

    // IF2 -> ID
    input  wire [31:0] if2_instr,
    input  wire [31:0] if2_pc,
    input  wire        if2_valid,

    // WB -> regfile 写口
    input  wire        wb_wen,
    input  wire [4:0]  wb_waddr,
    input  wire [31:0] wb_wdata,

    // 给 hazard_unit 的组合信息
    output wire [4:0]  id_rs1_addr,
    output wire [4:0]  id_rs2_addr,
    output wire        id_rs1_used,
    output wire        id_rs2_used,
    output wire        id_valid,
    output wire        id_illegal,

    // ------------------------------------------------------------------
    // ID/EX 流水线寄存器输出
    // ------------------------------------------------------------------
    output reg         id_ex_valid,
    output reg  [31:0] id_ex_pc,
    output reg  [31:0] id_ex_instr,
    output reg  [31:0] id_ex_rs1_data,
    output reg  [31:0] id_ex_rs2_data,
    output reg  [4:0]  id_ex_rs1_addr,
    output reg  [4:0]  id_ex_rs2_addr,
    output reg  [4:0]  id_ex_rd_addr,
    output reg  [31:0] id_ex_imm,

    output reg         id_ex_wb_en,
    output reg  [2:0]  id_ex_wb_src,

    output reg  [1:0]  id_ex_alu_src1,
    output reg  [1:0]  id_ex_alu_src2,
    output reg  [3:0]  id_ex_alu_op,

    output reg         id_ex_mem_read,
    output reg         id_ex_mem_write,
    output reg  [1:0]  id_ex_mem_size,
    output reg         id_ex_mem_unsigned,

    output reg         id_ex_branch,
    output reg  [3:0]  id_ex_branch_type,
    output reg  [1:0]  id_ex_pc_src,

    output reg         id_ex_is_load,
    output reg         id_ex_is_store,
    output reg         id_ex_is_jal,
    output reg         id_ex_is_jalr,
    output reg         id_ex_illegal,

    // ------------------------------------------------------------------
    // CSR / SYSTEM
    // ------------------------------------------------------------------
    output reg         id_ex_csr,
    output reg  [11:0] id_ex_csr_addr,
    output reg  [1:0]  id_ex_csr_op,
    output reg         id_ex_csr_src_is_imm,
    output reg         id_ex_csr_wen,

    output reg         id_ex_ecall,
    output reg         id_ex_ebreak,
    output reg         id_ex_mret,
    output reg         id_ex_fence,
    output reg         id_ex_fence_i
);

    // ------------------------------------------------------------------
    // Decoder outputs
    // ------------------------------------------------------------------
    wire [4:0]  dec_rs1_addr;
    wire [4:0]  dec_rs2_addr;
    wire [4:0]  dec_rd_addr;
    wire        dec_rs1_used;
    wire        dec_rs2_used;
    wire [31:0] dec_imm;
    wire        dec_illegal;
    wire        dec_system_instr;
    wire        dec_wb_en;
    wire [2:0]  dec_wb_src;
    wire [1:0]  dec_alu_src1;
    wire [1:0]  dec_alu_src2;
    wire [3:0]  dec_alu_op;
    wire        dec_mem_read;
    wire        dec_mem_write;
    wire [1:0]  dec_mem_size;
    wire        dec_mem_unsigned;
    wire        dec_branch;
    wire [3:0]  dec_branch_type;
    wire [1:0]  dec_pc_src;
    wire        dec_is_load;
    wire        dec_is_store;
    wire        dec_is_branch;
    wire        dec_is_jal;
    wire        dec_is_jalr;

    wire        dec_csr;
    wire [11:0] dec_csr_addr;
    wire [1:0]  dec_csr_op;
    wire        dec_csr_src_is_imm;
    wire        dec_csr_wen;
    wire        dec_ecall;
    wire        dec_ebreak;
    wire        dec_mret;
    wire        dec_fence;
    wire        dec_fence_i;

    decoder u_decoder (
        .instr           (if2_instr),
        .rs1_addr        (dec_rs1_addr),
        .rs2_addr        (dec_rs2_addr),
        .rd_addr         (dec_rd_addr),
        .rs1_used        (dec_rs1_used),
        .rs2_used        (dec_rs2_used),
        .imm             (dec_imm),
        .illegal         (dec_illegal),
        .system_instr    (dec_system_instr),
        .wb_en           (dec_wb_en),
        .wb_src          (dec_wb_src),
        .alu_src1        (dec_alu_src1),
        .alu_src2        (dec_alu_src2),
        .alu_op          (dec_alu_op),
        .mem_read        (dec_mem_read),
        .mem_write       (dec_mem_write),
        .mem_size        (dec_mem_size),
        .mem_unsigned    (dec_mem_unsigned),
        .branch          (dec_branch),
        .branch_type     (dec_branch_type),
        .pc_src          (dec_pc_src),
        .is_load         (dec_is_load),
        .is_store        (dec_is_store),
        .is_branch       (dec_is_branch),
        .is_jal          (dec_is_jal),
        .is_jalr         (dec_is_jalr),
        .csr             (dec_csr),
        .csr_addr        (dec_csr_addr),
        .csr_op          (dec_csr_op),
        .csr_src_is_imm  (dec_csr_src_is_imm),
        .csr_wen         (dec_csr_wen),
        .ecall           (dec_ecall),
        .ebreak          (dec_ebreak),
        .mret            (dec_mret),
        .fence           (dec_fence),
        .fence_i         (dec_fence_i)
    );

    // ------------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------------
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    regfile u_regfile (
        .clk   (clk),
        .wen   (wb_wen),
        .waddr (wb_waddr),
        .wdata (wb_wdata),
        .rs1   (dec_rs1_addr),
        .rs2   (dec_rs2_addr),
        .rd1   (rs1_data),
        .rd2   (rs2_data)
    );

    // ------------------------------------------------------------------
    // To hazard unit
    // ------------------------------------------------------------------
    assign id_rs1_addr = dec_rs1_addr;
    assign id_rs2_addr = dec_rs2_addr;
    assign id_rs1_used = dec_rs1_used;
    assign id_rs2_used = dec_rs2_used;

    // 非法指令也要进入 EX 触发异常，因此 valid 只由 if2_valid 决定
    assign id_valid   = if2_valid;
    assign id_illegal = if2_valid && dec_illegal;

    // ------------------------------------------------------------------
    // ID/EX pipeline register
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_valid        <= 1'b0;
            id_ex_pc           <= 32'd0;
            id_ex_instr        <= `NOP;
            id_ex_rs1_data     <= 32'd0;
            id_ex_rs2_data     <= 32'd0;
            id_ex_rs1_addr     <= 5'd0;
            id_ex_rs2_addr     <= 5'd0;
            id_ex_rd_addr      <= 5'd0;
            id_ex_imm          <= 32'd0;
            id_ex_wb_en        <= 1'b0;
            id_ex_wb_src       <= `WB_ALU;
            id_ex_alu_src1     <= `ALUSRC1_RS1;
            id_ex_alu_src2     <= `ALUSRC2_RS2;
            id_ex_alu_op       <= `ALU_ADD;
            id_ex_mem_read     <= 1'b0;
            id_ex_mem_write    <= 1'b0;
            id_ex_mem_size     <= `MEM_WORD;
            id_ex_mem_unsigned <= 1'b0;
            id_ex_branch       <= 1'b0;
            id_ex_branch_type  <= `BR_NONE;
            id_ex_pc_src       <= `PC_NEXT;
            id_ex_is_load      <= 1'b0;
            id_ex_is_store     <= 1'b0;
            id_ex_is_jal       <= 1'b0;
            id_ex_is_jalr      <= 1'b0;
            id_ex_illegal      <= 1'b0;
            id_ex_csr          <= 1'b0;
            id_ex_csr_addr     <= 12'd0;
            id_ex_csr_op       <= `CSR_OP_NONE;
            id_ex_csr_src_is_imm <= 1'b0;
            id_ex_csr_wen      <= 1'b0;
            id_ex_ecall        <= 1'b0;
            id_ex_ebreak       <= 1'b0;
            id_ex_mret         <= 1'b0;
            id_ex_fence        <= 1'b0;
            id_ex_fence_i      <= 1'b0;
        end else if (flush) begin
            id_ex_valid        <= 1'b0;
            id_ex_wb_en        <= 1'b0;
            id_ex_mem_read     <= 1'b0;
            id_ex_mem_write    <= 1'b0;
            id_ex_branch       <= 1'b0;
            id_ex_is_load      <= 1'b0;
            id_ex_is_store     <= 1'b0;
            id_ex_is_jal       <= 1'b0;
            id_ex_is_jalr      <= 1'b0;
            id_ex_illegal      <= 1'b0;
            id_ex_csr          <= 1'b0;
            id_ex_csr_wen      <= 1'b0;
            id_ex_ecall        <= 1'b0;
            id_ex_ebreak       <= 1'b0;
            id_ex_mret         <= 1'b0;
            id_ex_fence        <= 1'b0;
            id_ex_fence_i      <= 1'b0;
        end else if (stall) begin
            id_ex_valid        <= 1'b0;
            id_ex_wb_en        <= 1'b0;
            id_ex_mem_read     <= 1'b0;
            id_ex_mem_write    <= 1'b0;
            id_ex_branch       <= 1'b0;
            id_ex_is_load      <= 1'b0;
            id_ex_is_store     <= 1'b0;
            id_ex_is_jal       <= 1'b0;
            id_ex_is_jalr      <= 1'b0;
            id_ex_illegal      <= 1'b0;
            id_ex_csr          <= 1'b0;
            id_ex_csr_wen      <= 1'b0;
            id_ex_ecall        <= 1'b0;
            id_ex_ebreak       <= 1'b0;
            id_ex_mret         <= 1'b0;
            id_ex_fence        <= 1'b0;
            id_ex_fence_i      <= 1'b0;
        end else begin
            id_ex_valid        <= if2_valid;
            id_ex_pc           <= if2_pc;
            id_ex_instr        <= if2_instr;
            id_ex_rs1_data     <= rs1_data;
            id_ex_rs2_data     <= rs2_data;
            id_ex_rs1_addr     <= dec_rs1_addr;
            id_ex_rs2_addr     <= dec_rs2_addr;
            id_ex_rd_addr      <= dec_rd_addr;
            id_ex_imm          <= dec_imm;
            id_ex_wb_en        <= dec_wb_en && !dec_illegal;
            id_ex_wb_src       <= dec_wb_src;
            id_ex_alu_src1     <= dec_alu_src1;
            id_ex_alu_src2     <= dec_alu_src2;
            id_ex_alu_op       <= dec_alu_op;
            id_ex_mem_read     <= dec_mem_read && !dec_illegal;
            id_ex_mem_write    <= dec_mem_write && !dec_illegal;
            id_ex_mem_size     <= dec_mem_size;
            id_ex_mem_unsigned <= dec_mem_unsigned;
            id_ex_branch       <= dec_branch && !dec_illegal;
            id_ex_branch_type  <= dec_branch_type;
            id_ex_pc_src       <= dec_pc_src;
            id_ex_is_load      <= dec_is_load && !dec_illegal;
            id_ex_is_store     <= dec_is_store && !dec_illegal;
            id_ex_is_jal       <= dec_is_jal && !dec_illegal;
            id_ex_is_jalr      <= dec_is_jalr && !dec_illegal;
            id_ex_illegal      <= dec_illegal;
            id_ex_csr          <= dec_csr && !dec_illegal;
            id_ex_csr_addr     <= dec_csr_addr;
            id_ex_csr_op       <= dec_csr_op;
            id_ex_csr_src_is_imm <= dec_csr_src_is_imm;
            id_ex_csr_wen      <= dec_csr_wen && !dec_illegal;
            id_ex_ecall        <= dec_ecall;
            id_ex_ebreak       <= dec_ebreak;
            id_ex_mret         <= dec_mret;
            id_ex_fence        <= dec_fence;
            id_ex_fence_i      <= dec_fence_i;
        end
    end

endmodule
