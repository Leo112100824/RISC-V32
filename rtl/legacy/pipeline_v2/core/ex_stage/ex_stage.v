`include "../../riscv_def.vh"

// ============================================================================
//  ex_stage
//
//  流水线第 4 级：前递选择 + ALU + 分支/跳转解析，并包含 EX/MEM 流水线
//  寄存器。
//
//  分支在 EX 解析（静态预测不跳转）：
//    - 条件分支 taken -> redirect
//    - JAL / JALR      -> redirect
//  重定向信号直接回送 IF1，同时 core 用它 flush IF2 与 ID/EX。
//  由于取指是 IF1/IF2 两级，taken 时实际冲刷 3 级。
// ============================================================================
module ex_stage (
    input  wire                         clk                        ,
    input  wire                         rst_n                      ,

    // ------------------------------------------------------------------
    // ID/EX
    // ------------------------------------------------------------------
    input  wire                         id_ex_valid                ,
    input  wire        [  31:0]         id_ex_pc                   ,
    input  wire        [  31:0]         id_ex_rs1_data             ,
    input  wire        [  31:0]         id_ex_rs2_data             ,
    input  wire        [   4:0]         id_ex_rs1_addr             ,
    input  wire        [   4:0]         id_ex_rs2_addr             ,
    input  wire        [   4:0]         id_ex_rd_addr              ,
    input  wire        [  31:0]         id_ex_imm                  ,

    input  wire                         id_ex_wb_en                ,
    input  wire        [   2:0]         id_ex_wb_src               ,

    input  wire        [   1:0]         id_ex_alu_src1             ,
    input  wire        [   1:0]         id_ex_alu_src2             ,
    input  wire        [   3:0]         id_ex_alu_op               ,

    input  wire                         id_ex_mem_read             ,
    input  wire                         id_ex_mem_write            ,
    input  wire        [   1:0]         id_ex_mem_size             ,
    input  wire                         id_ex_mem_unsigned         ,

    input  wire                         id_ex_branch               ,
    input  wire        [   3:0]         id_ex_branch_type          ,

    input  wire                         id_ex_is_load              ,
    input  wire                         id_ex_is_store             ,
    input  wire                         id_ex_is_jal               ,
    input  wire                         id_ex_is_jalr              ,
    input  wire                         id_ex_illegal              ,

    // ------------------------------------------------------------------
    // MEM/WB 前递数据
    // ------------------------------------------------------------------
    input  wire        [  31:0]         mem_wb_wb_data             ,
    input  wire                         mem_wb_valid               ,
    input  wire                         mem_wb_wb_en               ,
    input  wire        [   4:0]         mem_wb_rd_addr             ,

    // ------------------------------------------------------------------
    // Redirect to IF1
    // ------------------------------------------------------------------
    output wire                         ex_redirect                ,
    output wire        [  31:0]         ex_redirect_pc             ,

    // ------------------------------------------------------------------
    // EX/MEM pipeline register
    // ------------------------------------------------------------------
    output reg                          ex_mem_valid               ,
    output reg         [  31:0]         ex_mem_pc                  ,
    output reg         [  31:0]         ex_mem_pc_plus4            ,
    output reg         [  31:0]         ex_mem_alu_result          ,
    output reg         [  31:0]         ex_mem_store_data          ,
    output reg         [   4:0]         ex_mem_rd_addr             ,
    output reg         [  31:0]         ex_mem_imm                 ,

    output reg                          ex_mem_wb_en               ,
    output reg         [   2:0]         ex_mem_wb_src              ,

    output reg                          ex_mem_mem_read            ,
    output reg                          ex_mem_mem_write           ,
    output reg         [   1:0]         ex_mem_mem_size            ,
    output reg                          ex_mem_mem_unsigned        ,

    output reg                          ex_mem_is_load             ,
    output reg                          ex_mem_is_store            ,
    output reg                          ex_mem_illegal              
);

    // ------------------------------------------------------------------
    // 数据前递
    // ------------------------------------------------------------------
    wire [1:0] fwd_a;
    wire [1:0] fwd_b;

    forward_unit u_forward_unit (
        .rs1_addr        (id_ex_rs1_addr),
        .rs2_addr        (id_ex_rs2_addr),
        .ex_mem_valid    (ex_mem_valid),
        .ex_mem_wb_en    (ex_mem_wb_en),
        .ex_mem_is_load  (ex_mem_is_load),
        .ex_mem_rd_addr  (ex_mem_rd_addr),
        .mem_wb_valid    (mem_wb_valid),
        .mem_wb_wb_en    (mem_wb_wb_en),
        .mem_wb_rd_addr  (mem_wb_rd_addr),
        .fwd_a           (fwd_a),
        .fwd_b           (fwd_b)
    );

    wire [31:0] rs1_fwd;
    wire [31:0] rs2_fwd;

    assign rs1_fwd = (fwd_a == 2'd1) ? ex_mem_alu_result :
                     (fwd_a == 2'd2) ? mem_wb_wb_data   :
                                       id_ex_rs1_data;

    assign rs2_fwd = (fwd_b == 2'd1) ? ex_mem_alu_result :
                     (fwd_b == 2'd2) ? mem_wb_wb_data   :
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

    assign ex_redirect = id_ex_valid && (id_ex_is_jal || id_ex_is_jalr || taken_branch);

    // JALR 目标是 (rs1 + imm) & ~1；JAL 与条件分支都是 PC + imm
    assign ex_redirect_pc = id_ex_is_jalr ? {alu_result[`XLEN-1:1], 1'b0}
                                          : (id_ex_pc + id_ex_imm);

    // ------------------------------------------------------------------
    // EX/MEM pipeline register
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_valid        <= 1'b0;
            ex_mem_pc           <= 32'd0;
            ex_mem_pc_plus4     <= 32'd0;
            ex_mem_alu_result   <= 32'd0;
            ex_mem_store_data   <= 32'd0;
            ex_mem_rd_addr      <= 5'd0;
            ex_mem_imm          <= 32'd0;
            ex_mem_wb_en        <= 1'b0;
            ex_mem_wb_src       <= `WB_ALU;
            ex_mem_mem_read     <= 1'b0;
            ex_mem_mem_write    <= 1'b0;
            ex_mem_mem_size     <= `MEM_WORD;
            ex_mem_mem_unsigned <= 1'b0;
            ex_mem_is_load      <= 1'b0;
            ex_mem_is_store     <= 1'b0;
            ex_mem_illegal      <= 1'b0;
        end else begin
            ex_mem_valid        <= id_ex_valid;
            ex_mem_pc           <= id_ex_pc;
            ex_mem_pc_plus4     <= id_ex_pc + 32'd4;
            ex_mem_alu_result   <= alu_result;
            ex_mem_store_data   <= rs2_fwd;
            ex_mem_rd_addr      <= id_ex_rd_addr;
            ex_mem_imm          <= id_ex_imm;
            ex_mem_wb_en        <= id_ex_wb_en && !id_ex_illegal;
            ex_mem_wb_src       <= id_ex_wb_src;
            ex_mem_mem_read     <= id_ex_mem_read && !id_ex_illegal;
            ex_mem_mem_write    <= id_ex_mem_write && !id_ex_illegal;
            ex_mem_mem_size     <= id_ex_mem_size;
            ex_mem_mem_unsigned <= id_ex_mem_unsigned;
            ex_mem_is_load      <= id_ex_is_load && !id_ex_illegal;
            ex_mem_is_store     <= id_ex_is_store && !id_ex_illegal;
            ex_mem_illegal      <= id_ex_illegal;
        end
    end

endmodule
