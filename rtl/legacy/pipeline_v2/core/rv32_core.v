`include "../riscv_def.vh"

// ============================================================================
//  rv32_core  ——  六级流水线小顶层
//
//  流水线划分（取指为同步读，IF 拆两级）：
//
//      IF1  ->  IF2  ->  ID  ->  EX  ->  MEM  ->  WB
//      PC/地址   捕获指令   译码    执行    访存    写回
//
//  每一级模块内部都包含自己的输出流水线寄存器：
//      if1_stage : PC
//      if2_stage : IF2/ID
//      id_stage  : ID/EX
//      ex_stage  : EX/MEM
//      mem_stage : MEM/WB
//      wb_stage  : 纯组合，写回 regfile
//
//  top.v 只实例化本模块并连接存储器接口。
// ============================================================================
module rv32_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory (synchronous read)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data memory
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_wmask,
    output wire        mem_ren,
    output wire        mem_wen,
    input  wire [31:0] mem_rdata,

    // Debug / testbench
    output wire        illegal_instr
);

    // ========================================================================
    // IF1 <-> IF2
    // ========================================================================
    wire [31:0] if1_pc_q;
    wire        if1_data_valid;

    wire [31:0] if2_instr;
    wire [31:0] if2_pc;
    wire        if2_valid;

    // ========================================================================
    // ID <-> hazard
    // ========================================================================
    wire [4:0]  id_rs1_addr;
    wire [4:0]  id_rs2_addr;
    wire        id_rs1_used;
    wire        id_rs2_used;
    wire        id_valid;
    wire        id_illegal;

    // ========================================================================
    // ID/EX
    // ========================================================================
    wire        id_ex_valid;
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_rs1_data;
    wire [31:0] id_ex_rs2_data;
    wire [4:0]  id_ex_rs1_addr;
    wire [4:0]  id_ex_rs2_addr;
    wire [4:0]  id_ex_rd_addr;
    wire [31:0] id_ex_imm;
    wire        id_ex_wb_en;
    wire [2:0]  id_ex_wb_src;
    wire [1:0]  id_ex_alu_src1;
    wire [1:0]  id_ex_alu_src2;
    wire [3:0]  id_ex_alu_op;
    wire        id_ex_mem_read;
    wire        id_ex_mem_write;
    wire [1:0]  id_ex_mem_size;
    wire        id_ex_mem_unsigned;
    wire        id_ex_branch;
    wire [3:0]  id_ex_branch_type;
    wire [1:0]  id_ex_pc_src;
    wire        id_ex_is_load;
    wire        id_ex_is_store;
    wire        id_ex_is_jal;
    wire        id_ex_is_jalr;
    wire        id_ex_illegal;

    // ========================================================================
    // EX/MEM
    // ========================================================================
    wire        ex_mem_valid;
    wire [31:0] ex_mem_pc;
    wire [31:0] ex_mem_pc_plus4;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_store_data;
    wire [4:0]  ex_mem_rd_addr;
    wire [31:0] ex_mem_imm;
    wire        ex_mem_wb_en;
    wire [2:0]  ex_mem_wb_src;
    wire        ex_mem_mem_read;
    wire        ex_mem_mem_write;
    wire [1:0]  ex_mem_mem_size;
    wire        ex_mem_mem_unsigned;
    wire        ex_mem_is_load;
    wire        ex_mem_is_store;
    wire        ex_mem_illegal;

    // ========================================================================
    // MEM/WB
    // ========================================================================
    wire        mem_wb_valid;
    wire        mem_wb_wb_en;
    wire [4:0]  mem_wb_rd_addr;
    wire [31:0] mem_wb_wb_data;

    // ========================================================================
    // WB -> regfile
    // ========================================================================
    wire        wb_wen;
    wire [4:0]  wb_waddr;
    wire [31:0] wb_wdata;

    // ========================================================================
    // Control
    // ========================================================================
    wire        ex_redirect;
    wire [31:0] ex_redirect_pc;
    wire        stall;

    // ========================================================================
    // IF1
    // ========================================================================
    if1_stage u_if1_stage (
        .clk             (clk),
        .rst_n           (rst_n),
        .redirect        (ex_redirect),
        .redirect_pc     (ex_redirect_pc),
        .stall           (stall),
        .imem_addr       (imem_addr),
        .if1_pc_q        (if1_pc_q),
        .if1_data_valid  (if1_data_valid)
    );

    // ========================================================================
    // IF2
    // ========================================================================
    if2_stage u_if2_stage (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush           (ex_redirect),
        .stall           (stall),
        .imem_rdata      (imem_rdata),
        .if1_pc_q        (if1_pc_q),
        .if1_data_valid  (if1_data_valid),
        .if2_instr       (if2_instr),
        .if2_pc          (if2_pc),
        .if2_valid       (if2_valid)
    );

    // ========================================================================
    // Hazard detection
    // ========================================================================
    hazard_unit u_hazard_unit (
        .id_ex_valid     (id_ex_valid),
        .id_ex_mem_read  (id_ex_mem_read),
        .id_ex_rd_addr   (id_ex_rd_addr),
        .id_valid        (id_valid),
        .id_illegal      (id_illegal),
        .id_rs1_used     (id_rs1_used),
        .id_rs2_used     (id_rs2_used),
        .id_rs1_addr     (id_rs1_addr),
        .id_rs2_addr     (id_rs2_addr),
        .stall           (stall)
    );

    // ========================================================================
    // ID
    // ========================================================================
    id_stage u_id_stage (
        .clk               (clk),
        .rst_n             (rst_n),
        .stall             (stall),
        .flush             (ex_redirect),
        .if2_instr         (if2_instr),
        .if2_pc            (if2_pc),
        .if2_valid         (if2_valid),
        .wb_wen            (wb_wen),
        .wb_waddr          (wb_waddr),
        .wb_wdata          (wb_wdata),
        .id_rs1_addr       (id_rs1_addr),
        .id_rs2_addr       (id_rs2_addr),
        .id_rs1_used       (id_rs1_used),
        .id_rs2_used       (id_rs2_used),
        .id_valid          (id_valid),
        .id_illegal        (id_illegal),
        .id_ex_valid       (id_ex_valid),
        .id_ex_pc          (id_ex_pc),
        .id_ex_rs1_data    (id_ex_rs1_data),
        .id_ex_rs2_data    (id_ex_rs2_data),
        .id_ex_rs1_addr    (id_ex_rs1_addr),
        .id_ex_rs2_addr    (id_ex_rs2_addr),
        .id_ex_rd_addr     (id_ex_rd_addr),
        .id_ex_imm         (id_ex_imm),
        .id_ex_wb_en       (id_ex_wb_en),
        .id_ex_wb_src      (id_ex_wb_src),
        .id_ex_alu_src1    (id_ex_alu_src1),
        .id_ex_alu_src2    (id_ex_alu_src2),
        .id_ex_alu_op      (id_ex_alu_op),
        .id_ex_mem_read    (id_ex_mem_read),
        .id_ex_mem_write   (id_ex_mem_write),
        .id_ex_mem_size    (id_ex_mem_size),
        .id_ex_mem_unsigned(id_ex_mem_unsigned),
        .id_ex_branch      (id_ex_branch),
        .id_ex_branch_type (id_ex_branch_type),
        .id_ex_pc_src      (id_ex_pc_src),
        .id_ex_is_load     (id_ex_is_load),
        .id_ex_is_store    (id_ex_is_store),
        .id_ex_is_jal      (id_ex_is_jal),
        .id_ex_is_jalr     (id_ex_is_jalr),
        .id_ex_illegal     (id_ex_illegal)
    );

    // ========================================================================
    // EX
    // ========================================================================
    ex_stage u_ex_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .id_ex_valid        (id_ex_valid),
        .id_ex_pc           (id_ex_pc),
        .id_ex_rs1_data     (id_ex_rs1_data),
        .id_ex_rs2_data     (id_ex_rs2_data),
        .id_ex_rs1_addr     (id_ex_rs1_addr),
        .id_ex_rs2_addr     (id_ex_rs2_addr),
        .id_ex_rd_addr      (id_ex_rd_addr),
        .id_ex_imm          (id_ex_imm),
        .id_ex_wb_en        (id_ex_wb_en),
        .id_ex_wb_src       (id_ex_wb_src),
        .id_ex_alu_src1     (id_ex_alu_src1),
        .id_ex_alu_src2     (id_ex_alu_src2),
        .id_ex_alu_op       (id_ex_alu_op),
        .id_ex_mem_read     (id_ex_mem_read),
        .id_ex_mem_write    (id_ex_mem_write),
        .id_ex_mem_size     (id_ex_mem_size),
        .id_ex_mem_unsigned (id_ex_mem_unsigned),
        .id_ex_branch       (id_ex_branch),
        .id_ex_branch_type  (id_ex_branch_type),
        .id_ex_is_load      (id_ex_is_load),
        .id_ex_is_store     (id_ex_is_store),
        .id_ex_is_jal       (id_ex_is_jal),
        .id_ex_is_jalr      (id_ex_is_jalr),
        .id_ex_illegal      (id_ex_illegal),
        .mem_wb_wb_data     (mem_wb_wb_data),
        .mem_wb_valid       (mem_wb_valid),
        .mem_wb_wb_en       (mem_wb_wb_en),
        .mem_wb_rd_addr     (mem_wb_rd_addr),
        .ex_redirect        (ex_redirect),
        .ex_redirect_pc     (ex_redirect_pc),
        .ex_mem_valid       (ex_mem_valid),
        .ex_mem_pc          (ex_mem_pc),
        .ex_mem_pc_plus4    (ex_mem_pc_plus4),
        .ex_mem_alu_result  (ex_mem_alu_result),
        .ex_mem_store_data  (ex_mem_store_data),
        .ex_mem_rd_addr     (ex_mem_rd_addr),
        .ex_mem_imm         (ex_mem_imm),
        .ex_mem_wb_en       (ex_mem_wb_en),
        .ex_mem_wb_src      (ex_mem_wb_src),
        .ex_mem_mem_read    (ex_mem_mem_read),
        .ex_mem_mem_write   (ex_mem_mem_write),
        .ex_mem_mem_size    (ex_mem_mem_size),
        .ex_mem_mem_unsigned(ex_mem_mem_unsigned),
        .ex_mem_is_load     (ex_mem_is_load),
        .ex_mem_is_store    (ex_mem_is_store),
        .ex_mem_illegal     (ex_mem_illegal)
    );

    // ========================================================================
    // MEM
    // ========================================================================
    mem_stage u_mem_stage (
        .clk                 (clk),
        .rst_n               (rst_n),
        .ex_mem_valid        (ex_mem_valid),
        .ex_mem_pc           (ex_mem_pc),
        .ex_mem_pc_plus4     (ex_mem_pc_plus4),
        .ex_mem_alu_result   (ex_mem_alu_result),
        .ex_mem_store_data   (ex_mem_store_data),
        .ex_mem_rd_addr      (ex_mem_rd_addr),
        .ex_mem_imm          (ex_mem_imm),
        .ex_mem_wb_en        (ex_mem_wb_en),
        .ex_mem_wb_src       (ex_mem_wb_src),
        .ex_mem_mem_read     (ex_mem_mem_read),
        .ex_mem_mem_write    (ex_mem_mem_write),
        .ex_mem_mem_size     (ex_mem_mem_size),
        .ex_mem_mem_unsigned (ex_mem_mem_unsigned),
        .ex_mem_is_load      (ex_mem_is_load),
        .ex_mem_is_store     (ex_mem_is_store),
        .ex_mem_illegal      (ex_mem_illegal),
        .mem_rdata           (mem_rdata),
        .mem_addr            (mem_addr),
        .mem_wdata           (mem_wdata),
        .mem_wmask           (mem_wmask),
        .mem_ren             (mem_ren),
        .mem_wen             (mem_wen),
        .mem_wb_valid        (mem_wb_valid),
        .mem_wb_wb_en        (mem_wb_wb_en),
        .mem_wb_rd_addr      (mem_wb_rd_addr),
        .mem_wb_wb_data      (mem_wb_wb_data)
    );

    // ========================================================================
    // WB
    // ========================================================================
    wb_stage u_wb_stage (
        .mem_wb_valid   (mem_wb_valid),
        .mem_wb_wb_en   (mem_wb_wb_en),
        .mem_wb_rd_addr (mem_wb_rd_addr),
        .mem_wb_wb_data (mem_wb_wb_data),
        .wb_wen         (wb_wen),
        .wb_waddr       (wb_waddr),
        .wb_wdata       (wb_wdata)
    );

    // ========================================================================
    // Debug
    // ========================================================================
    assign illegal_instr = id_ex_valid && id_ex_illegal;

endmodule
