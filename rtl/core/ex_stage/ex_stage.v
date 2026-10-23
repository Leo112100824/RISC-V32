`include "../../riscv_def.vh"

// ============================================================================
//  ex_stage
//
//  流水线第 4 级：前递选择 + ALU + 分支/跳转解析 + 异常检测，
//  并包含 EX/MEM 流水线寄存器。
//
//  在 EX 解析的控制流：
//    - 条件分支 taken -> redirect
//    - JAL / JALR      -> redirect
//    - FENCE.I         -> redirect 到 PC+4（指令流同步）
//    - MRET            -> redirect 到 mepc
//  以下异常在 EX 触发：
//    - 非法指令 / ECALL / EBREAK
//    - 分支 / JAL / JALR / MRET 目标不是 4 字节对齐
//
//  MEM 级异常的优先级高于 EX：core 用 mem_trap 抑制本级的 redirect /
//  EX-MEM 有效位。
// ============================================================================
module ex_stage (
    input  wire        clk,
    input  wire        rst_n,

    // ------------------------------------------------------------------
    // ID/EX
    // ------------------------------------------------------------------
    input  wire        id_ex_valid,
    input  wire [31:0] id_ex_pc,
    input  wire [31:0] id_ex_instr,
    input  wire [31:0] id_ex_rs1_data,
    input  wire [31:0] id_ex_rs2_data,
    input  wire [4:0]  id_ex_rs1_addr,
    input  wire [4:0]  id_ex_rs2_addr,
    input  wire [4:0]  id_ex_rd_addr,
    input  wire [31:0] id_ex_imm,

    input  wire        id_ex_wb_en,
    input  wire [2:0]  id_ex_wb_src,

    input  wire [1:0]  id_ex_alu_src1,
    input  wire [1:0]  id_ex_alu_src2,
    input  wire [3:0]  id_ex_alu_op,

    input  wire        id_ex_mem_read,
    input  wire        id_ex_mem_write,
    input  wire [1:0]  id_ex_mem_size,
    input  wire        id_ex_mem_unsigned,

    input  wire        id_ex_branch,
    input  wire [3:0]  id_ex_branch_type,

    input  wire        id_ex_is_load,
    input  wire        id_ex_is_store,
    input  wire        id_ex_is_jal,
    input  wire        id_ex_is_jalr,
    input  wire        id_ex_illegal,

    input  wire        id_ex_csr,
    input  wire [11:0] id_ex_csr_addr,
    input  wire [1:0]  id_ex_csr_op,
    input  wire        id_ex_csr_src_is_imm,
    input  wire        id_ex_csr_wen,

    input  wire        id_ex_ecall,
    input  wire        id_ex_ebreak,
    input  wire        id_ex_mret,
    input  wire        id_ex_fence,
    input  wire        id_ex_fence_i,

    // ------------------------------------------------------------------
    // MEM/WB 前递数据
    // ------------------------------------------------------------------
    input  wire [31:0] mem_wb_wb_data,
    input  wire        mem_wb_valid,
    input  wire        mem_wb_wb_en,
    input  wire [4:0]  mem_wb_rd_addr,

    // ------------------------------------------------------------------
    // MEM 级异常（优先级更高）
    // ------------------------------------------------------------------
    input  wire        mem_trap,

    // ------------------------------------------------------------------
    // MRET 目标（core 已做 CSR 同拍写旁路）
    // ------------------------------------------------------------------
    input  wire [31:0] mepc_i,

    // ------------------------------------------------------------------
    // Redirect to IF1
    // ------------------------------------------------------------------
    output wire        ex_redirect,
    output wire [31:0] ex_redirect_pc,

    // ------------------------------------------------------------------
    // EX 级异常
    // ------------------------------------------------------------------
    output wire        ex_trap,
    output wire [3:0]  ex_trap_cause,
    output wire [31:0] ex_trap_tval,

    // ------------------------------------------------------------------
    // MRET commit（给 csr_file 更新 mstatus）
    // ------------------------------------------------------------------
    output wire        ex_mret_commit,

    // ------------------------------------------------------------------
    // EX/MEM pipeline register
    // ------------------------------------------------------------------
    output reg         ex_mem_valid,
    output reg  [31:0] ex_mem_pc,
    output reg  [31:0] ex_mem_pc_plus4,
    output reg  [31:0] ex_mem_instr,
    output reg  [31:0] ex_mem_alu_result,
    output reg  [31:0] ex_mem_store_data,
    output reg  [4:0]  ex_mem_rd_addr,
    output reg  [31:0] ex_mem_imm,

    output reg         ex_mem_wb_en,
    output reg  [2:0]  ex_mem_wb_src,

    output reg         ex_mem_mem_read,
    output reg         ex_mem_mem_write,
    output reg  [1:0]  ex_mem_mem_size,
    output reg         ex_mem_mem_unsigned,

    output reg         ex_mem_is_load,
    output reg         ex_mem_is_store,
    output reg         ex_mem_illegal,

    output reg         ex_mem_csr,
    output reg  [11:0] ex_mem_csr_addr,
    output reg  [1:0]  ex_mem_csr_op,
    output reg  [31:0] ex_mem_csr_src_data,
    output reg         ex_mem_csr_wen
);

    // ------------------------------------------------------------------
    // 数据前递
    // ------------------------------------------------------------------
    wire [1:0] fwd_a;
    wire [1:0] fwd_b;

    // EX/MEM 中可前递的最终写回值
    reg [31:0] ex_mem_wb_data;

    forward_unit u_forward_unit (
        .rs1_addr        (id_ex_rs1_addr),
        .rs2_addr        (id_ex_rs2_addr),
        .ex_mem_valid    (ex_mem_valid),
        .ex_mem_wb_en    (ex_mem_wb_en),
        .ex_mem_is_load  (ex_mem_is_load),
        .ex_mem_is_csr   (ex_mem_csr),
        .ex_mem_rd_addr  (ex_mem_rd_addr),
        .mem_wb_valid    (mem_wb_valid),
        .mem_wb_wb_en    (mem_wb_wb_en),
        .mem_wb_rd_addr  (mem_wb_rd_addr),
        .fwd_a           (fwd_a),
        .fwd_b           (fwd_b)
    );

    wire [31:0] rs1_fwd;
    wire [31:0] rs2_fwd;

    assign rs1_fwd = (fwd_a == 2'd1) ? ex_mem_wb_data :
                     (fwd_a == 2'd2) ? mem_wb_wb_data :
                                       id_ex_rs1_data;

    assign rs2_fwd = (fwd_b == 2'd1) ? ex_mem_wb_data :
                     (fwd_b == 2'd2) ? mem_wb_wb_data :
                                       id_ex_rs2_data;

    // ------------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------------
    wire [31:0] operand_a;
    wire [31:0] operand_b;

    assign operand_a = (id_ex_alu_src1 == `ALUSRC1_PC)  ? id_ex_pc  : rs1_fwd;
    assign operand_b = (id_ex_alu_src2 == `ALUSRC2_IMM) ? id_ex_imm : rs2_fwd;

    wire [31:0] alu_result;

    alu u_alu (
        .operand_a  (operand_a),
        .operand_b  (operand_b),
        .alu_op     (id_ex_alu_op),
        .alu_result (alu_result)
    );

    // EX 级可前递的最终写回值（load/CSR 不在此列）
    reg [31:0] ex_wb_data;

    always @(*) begin
        case (id_ex_wb_src)
            `WB_ALU: ex_wb_data = alu_result;
            `WB_PC4: ex_wb_data = id_ex_pc + 32'd4;
            `WB_IMM: ex_wb_data = id_ex_imm;
            default: ex_wb_data = 32'd0;
        endcase
    end

    // ------------------------------------------------------------------
    // Branch / jump resolution
    // ------------------------------------------------------------------
    wire        branch_taken;
    wire [31:0] branch_target;

    branch_unit u_branch_unit (
        .pc            (id_ex_pc),
        .rs1_data      (rs1_fwd),
        .rs2_data      (rs2_fwd),
        .imm           (id_ex_imm),
        .branch_en     (id_ex_branch),
        .branch_type   (id_ex_branch_type),
        .branch_taken  (branch_taken),
        .branch_target (branch_target)
    );

    wire taken_branch;
    assign taken_branch = id_ex_branch && branch_taken;

    // CSR 指令的源操作数：rs1 前递值或 zimm
    wire [31:0] csr_src_data;
    assign csr_src_data = id_ex_csr_src_is_imm ? {27'd0, id_ex_instr[19:15]}
                                               : rs1_fwd;

    // ------------------------------------------------------------------
    // Redirect target selection
    // ------------------------------------------------------------------
    wire [31:0] redirect_pc_calc;

    assign redirect_pc_calc = id_ex_mret    ? {mepc_i[31:2], 2'b00} :
                              id_ex_fence_i ? (id_ex_pc + 32'd4)    :
                              id_ex_is_jalr ? {alu_result[`XLEN-1:1], 1'b0} :
                                              (id_ex_pc + id_ex_imm);

    wire redirect_req;
    assign redirect_req = id_ex_valid &&
                          (id_ex_is_jal || id_ex_is_jalr || taken_branch ||
                           id_ex_mret  || id_ex_fence_i);

    wire target_misaligned;
    assign target_misaligned = redirect_req && (redirect_pc_calc[1:0] != 2'b00);

    // ------------------------------------------------------------------
    // Exception detection (EX)
    // ------------------------------------------------------------------
    wire sys_trap;
    assign sys_trap = id_ex_valid && (id_ex_illegal || id_ex_ecall || id_ex_ebreak);

    assign ex_trap = sys_trap || target_misaligned;

    assign ex_trap_cause = id_ex_illegal ? `EXC_ILLEGAL_INSTR :
                           id_ex_ecall   ? `EXC_ECALL_M       :
                           id_ex_ebreak  ? `EXC_BREAKPOINT    :
                           target_misaligned ? `EXC_INST_MISALIGNED :
                                           4'd0;

    assign ex_trap_tval = id_ex_illegal      ? id_ex_instr :
                          target_misaligned  ? redirect_pc_calc :
                                               32'd0;

    // ------------------------------------------------------------------
    // Control transfer / MRET
    // ------------------------------------------------------------------
    assign ex_redirect = redirect_req && !ex_trap && !mem_trap;

    assign ex_redirect_pc = redirect_pc_calc;

    assign ex_mret_commit = id_ex_valid && id_ex_mret && !ex_trap && !mem_trap;

    // ------------------------------------------------------------------
    // EX/MEM pipeline register
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_valid        <= 1'b0;
            ex_mem_pc           <= 32'd0;
            ex_mem_pc_plus4     <= 32'd0;
            ex_mem_instr        <= `NOP;
            ex_mem_alu_result   <= 32'd0;
            ex_mem_store_data   <= 32'd0;
            ex_mem_rd_addr      <= 5'd0;
            ex_mem_imm          <= 32'd0;
            ex_mem_wb_data      <= 32'd0;
            ex_mem_wb_en        <= 1'b0;
            ex_mem_wb_src       <= `WB_ALU;
            ex_mem_mem_read     <= 1'b0;
            ex_mem_mem_write    <= 1'b0;
            ex_mem_mem_size     <= `MEM_WORD;
            ex_mem_mem_unsigned <= 1'b0;
            ex_mem_is_load      <= 1'b0;
            ex_mem_is_store     <= 1'b0;
            ex_mem_illegal      <= 1'b0;
            ex_mem_csr          <= 1'b0;
            ex_mem_csr_addr     <= 12'd0;
            ex_mem_csr_op       <= `CSR_OP_NONE;
            ex_mem_csr_src_data <= 32'd0;
            ex_mem_csr_wen      <= 1'b0;
        end else begin
            // 异常 / MEM 级异常不允许产生 EX/MEM 副作用；
            // MRET / FENCE.I 允许作为无写回指令继续流向 WB，以便退休计数
            ex_mem_valid        <= id_ex_valid && !ex_trap && !mem_trap;
            ex_mem_pc           <= id_ex_pc;
            ex_mem_pc_plus4     <= id_ex_pc + 32'd4;
            ex_mem_instr        <= id_ex_instr;
            ex_mem_alu_result   <= alu_result;
            ex_mem_store_data   <= rs2_fwd;
            ex_mem_rd_addr      <= id_ex_rd_addr;
            ex_mem_imm          <= id_ex_imm;
            ex_mem_wb_data      <= ex_wb_data;
            ex_mem_wb_en        <= id_ex_wb_en && !ex_trap && !mem_trap;
            ex_mem_wb_src       <= id_ex_wb_src;
            ex_mem_mem_read     <= id_ex_mem_read && !ex_trap && !mem_trap;
            ex_mem_mem_write    <= id_ex_mem_write && !ex_trap && !mem_trap;
            ex_mem_mem_size     <= id_ex_mem_size;
            ex_mem_mem_unsigned <= id_ex_mem_unsigned;
            ex_mem_is_load      <= id_ex_is_load && !ex_trap && !mem_trap;
            ex_mem_is_store     <= id_ex_is_store && !ex_trap && !mem_trap;
            ex_mem_illegal      <= id_ex_illegal;
            ex_mem_csr          <= id_ex_csr && !ex_trap && !mem_trap;
            ex_mem_csr_addr     <= id_ex_csr_addr;
            ex_mem_csr_op       <= id_ex_csr_op;
            ex_mem_csr_src_data <= csr_src_data;
            ex_mem_csr_wen      <= id_ex_csr_wen && !ex_trap && !mem_trap;
        end
    end

endmodule
