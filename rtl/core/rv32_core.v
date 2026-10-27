`include "../riscv_def.vh"

// ============================================================================
//  rv32_core  ——  五级流水线小顶层（RV32I + Zicsr + Machine trap）
//
//      IF  ->  ID  ->  EX  ->  MEM  ->  WB
//      取指   译码   执行   访存   写回
//
//  每级模块自带输出流水线寄存器：
//      if_stage  : PC、同步指令返回对齐及 ID 停顿保持
//      id_stage  : ID/EX
//      ex_stage  : EX/MEM
//      mem_stage : MEM/WB
//      wb_stage  : 纯组合，写回 regfile
//
//  异常：
//      EX  级：非法指令、ECALL、EBREAK、目标非对齐
//      MEM 级：load/store 非对齐、CSR 未实现/写只读
//    MEM 级异常更老，优先级高于 EX；trap 统一跳到 mtvec，写 mepc/mcause/
//    mtval/mstatus，并冲刷年轻指令。
// ============================================================================
module rv32_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory (synchronous read)
    output wire [31:0] imem_addr,   //指令地址
    input  wire [31:0] imem_rdata,  //收到的指令数据

    // Data memory
    output wire [31:0] mem_addr,    //输出的数据地址
    output wire [31:0] mem_wdata,   //写数据
    output wire [3:0]  mem_wmask,   //输出的写数据掩码
    output wire        mem_ren,     //读使能
    output wire        mem_wen,     //写使能
    input  wire [31:0] mem_rdata,   //读数据

    // Trap observability (testbench / debug)
    output wire        trap,        //异常信号
    output wire [3:0]  trap_cause,  //异常原因
    output wire [31:0] trap_pc,     //异常的pc
    output wire [31:0] trap_tval    //异常附加信号
);

    // ========================================================================
    // IF -> ID
    // ========================================================================
    wire [31:0] if_instr;
    wire [31:0] if_pc;
    wire        if_valid;

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
    wire [31:0] id_ex_instr;
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
    wire        id_ex_csr;
    wire [11:0] id_ex_csr_addr;
    wire [1:0]  id_ex_csr_op;
    wire        id_ex_csr_src_is_imm;
    wire        id_ex_csr_wen;
    wire        id_ex_ecall;
    wire        id_ex_ebreak;
    wire        id_ex_mret;
    wire        id_ex_fence;
    wire        id_ex_fence_i;

    // ========================================================================
    // EX/MEM
    // ========================================================================
    wire        ex_mem_valid;
    wire [31:0] ex_mem_pc;
    wire [31:0] ex_mem_pc_plus4;
    wire [31:0] ex_mem_instr;
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
    wire        ex_mem_csr;
    wire [11:0] ex_mem_csr_addr;
    wire [1:0]  ex_mem_csr_op;
    wire [31:0] ex_mem_csr_src_data;
    wire        ex_mem_csr_wen;

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
    // Control / trap
    // ========================================================================
    wire        ex_redirect;
    wire [31:0] ex_redirect_pc;
    wire        ex_trap;
    wire [3:0]  ex_trap_cause;
    wire [31:0] ex_trap_tval;
    wire        ex_mret_commit;

    wire        mem_trap;
    wire [3:0]  mem_trap_cause;
    wire [31:0] mem_trap_tval;

    wire        trap_taken;
    wire [31:0] trap_pc_w;
    wire [3:0]  trap_cause_w;
    wire [31:0] trap_tval_w;

    wire        pc_redirect;
    wire [31:0] pc_redirect_pc;

    wire        stall;

    // 退休脉冲：所有有效指令都流向 MEM/WB；trap 指令的 valid 被清零
    wire        retire;
    assign retire = mem_wb_valid;

    // ========================================================================
    // CSR
    // ========================================================================
    wire        mem_csr_we;
    wire [11:0] mem_csr_waddr;
    wire [31:0] mem_csr_wdata;
    wire [31:0] csr_rdata;
    wire        csr_implemented;

    wire [31:0] mepc_o;
    wire [31:0] mstatus_o;
    wire [31:0] mtvec_o;

    wire [31:0] mepc_effective;
    wire [31:0] mtvec_effective;

    // ========================================================================
    // Trap priority: MEM is older than EX
    // ========================================================================
    assign trap_taken   = mem_trap | ex_trap;
    assign trap_pc_w    = mem_trap ? ex_mem_pc    : id_ex_pc;
    assign trap_cause_w = mem_trap ? mem_trap_cause : ex_trap_cause;
    assign trap_tval_w  = mem_trap ? mem_trap_tval  : ex_trap_tval;

    // 同拍 older CSR 写 mtvec/mepc 时，trap/MRET 必须看到新值
    assign mtvec_effective = (mem_csr_we && (mem_csr_waddr == `CSR_MTVEC))
                             ? mem_csr_wdata : mtvec_o;
    assign mepc_effective  = (mem_csr_we && (mem_csr_waddr == `CSR_MEPC))
                             ? mem_csr_wdata : mepc_o;

    assign pc_redirect    = trap_taken | ex_redirect;
    assign pc_redirect_pc = trap_taken ? {mtvec_effective[31:2], 2'b00}
                                       : ex_redirect_pc;

    assign trap      = trap_taken;
    assign trap_cause = trap_cause_w;
    assign trap_pc    = trap_pc_w;
    assign trap_tval  = trap_tval_w;

    // ========================================================================
    // IF
    // ========================================================================
    if_stage u_if_stage (
        .clk             (clk),
        .rst_n           (rst_n),
        .redirect        (pc_redirect),
        .redirect_pc     (pc_redirect_pc),
        .stall           (stall),
        .imem_addr       (imem_addr),
        .imem_rdata      (imem_rdata),
        .if_instr        (if_instr),
        .if_pc           (if_pc),
        .if_valid        (if_valid)
    );

    // ========================================================================
    // Hazard detection
    // ========================================================================
    hazard_unit u_hazard_unit (
        .id_ex_valid     (id_ex_valid),
        .id_ex_mem_read  (id_ex_mem_read),
        .id_ex_csr       (id_ex_csr),
        .id_ex_wb_en     (id_ex_wb_en),
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
        .clk                 (clk),
        .rst_n               (rst_n),
        .stall               (stall),
        .flush               (pc_redirect),
        .if_instr            (if_instr),
        .if_pc               (if_pc),
        .if_valid            (if_valid),
        .wb_wen              (wb_wen),
        .wb_waddr            (wb_waddr),
        .wb_wdata            (wb_wdata),
        .id_rs1_addr         (id_rs1_addr),
        .id_rs2_addr         (id_rs2_addr),
        .id_rs1_used         (id_rs1_used),
        .id_rs2_used         (id_rs2_used),
        .id_valid            (id_valid),
        .id_illegal          (id_illegal),
        .id_ex_valid         (id_ex_valid),
        .id_ex_pc            (id_ex_pc),
        .id_ex_instr         (id_ex_instr),
        .id_ex_rs1_data      (id_ex_rs1_data),
        .id_ex_rs2_data      (id_ex_rs2_data),
        .id_ex_rs1_addr      (id_ex_rs1_addr),
        .id_ex_rs2_addr      (id_ex_rs2_addr),
        .id_ex_rd_addr       (id_ex_rd_addr),
        .id_ex_imm           (id_ex_imm),
        .id_ex_wb_en         (id_ex_wb_en),
        .id_ex_wb_src        (id_ex_wb_src),
        .id_ex_alu_src1      (id_ex_alu_src1),
        .id_ex_alu_src2      (id_ex_alu_src2),
        .id_ex_alu_op        (id_ex_alu_op),
        .id_ex_mem_read      (id_ex_mem_read),
        .id_ex_mem_write     (id_ex_mem_write),
        .id_ex_mem_size      (id_ex_mem_size),
        .id_ex_mem_unsigned  (id_ex_mem_unsigned),
        .id_ex_branch        (id_ex_branch),
        .id_ex_branch_type   (id_ex_branch_type),
        .id_ex_pc_src        (id_ex_pc_src),
        .id_ex_is_load       (id_ex_is_load),
        .id_ex_is_store      (id_ex_is_store),
        .id_ex_is_jal        (id_ex_is_jal),
        .id_ex_is_jalr       (id_ex_is_jalr),
        .id_ex_illegal       (id_ex_illegal),
        .id_ex_csr           (id_ex_csr),
        .id_ex_csr_addr      (id_ex_csr_addr),
        .id_ex_csr_op        (id_ex_csr_op),
        .id_ex_csr_src_is_imm(id_ex_csr_src_is_imm),
        .id_ex_csr_wen       (id_ex_csr_wen),
        .id_ex_ecall         (id_ex_ecall),
        .id_ex_ebreak        (id_ex_ebreak),
        .id_ex_mret          (id_ex_mret),
        .id_ex_fence         (id_ex_fence),
        .id_ex_fence_i       (id_ex_fence_i)
    );

    // ========================================================================
    // EX
    // ========================================================================
    ex_stage u_ex_stage (
        .clk                 (clk),
        .rst_n               (rst_n),
        .id_ex_valid         (id_ex_valid),
        .id_ex_pc            (id_ex_pc),
        .id_ex_instr         (id_ex_instr),
        .id_ex_rs1_data      (id_ex_rs1_data),
        .id_ex_rs2_data      (id_ex_rs2_data),
        .id_ex_rs1_addr      (id_ex_rs1_addr),
        .id_ex_rs2_addr      (id_ex_rs2_addr),
        .id_ex_rd_addr       (id_ex_rd_addr),
        .id_ex_imm           (id_ex_imm),
        .id_ex_wb_en         (id_ex_wb_en),
        .id_ex_wb_src        (id_ex_wb_src),
        .id_ex_alu_src1      (id_ex_alu_src1),
        .id_ex_alu_src2      (id_ex_alu_src2),
        .id_ex_alu_op        (id_ex_alu_op),
        .id_ex_mem_read      (id_ex_mem_read),
        .id_ex_mem_write     (id_ex_mem_write),
        .id_ex_mem_size      (id_ex_mem_size),
        .id_ex_mem_unsigned  (id_ex_mem_unsigned),
        .id_ex_branch        (id_ex_branch),
        .id_ex_branch_type   (id_ex_branch_type),
        .id_ex_is_load       (id_ex_is_load),
        .id_ex_is_store      (id_ex_is_store),
        .id_ex_is_jal        (id_ex_is_jal),
        .id_ex_is_jalr       (id_ex_is_jalr),
        .id_ex_illegal       (id_ex_illegal),
        .id_ex_csr           (id_ex_csr),
        .id_ex_csr_addr      (id_ex_csr_addr),
        .id_ex_csr_op        (id_ex_csr_op),
        .id_ex_csr_src_is_imm(id_ex_csr_src_is_imm),
        .id_ex_csr_wen       (id_ex_csr_wen),
        .id_ex_ecall         (id_ex_ecall),
        .id_ex_ebreak        (id_ex_ebreak),
        .id_ex_mret          (id_ex_mret),
        .id_ex_fence         (id_ex_fence),
        .id_ex_fence_i       (id_ex_fence_i),
        .mem_wb_wb_data      (mem_wb_wb_data),
        .mem_wb_valid        (mem_wb_valid),
        .mem_wb_wb_en        (mem_wb_wb_en),
        .mem_wb_rd_addr      (mem_wb_rd_addr),
        .mem_trap            (mem_trap),
        .mepc_i              (mepc_effective),
        .ex_redirect         (ex_redirect),
        .ex_redirect_pc      (ex_redirect_pc),
        .ex_trap             (ex_trap),
        .ex_trap_cause       (ex_trap_cause),
        .ex_trap_tval        (ex_trap_tval),
        .ex_mret_commit      (ex_mret_commit),
        .ex_mem_valid        (ex_mem_valid),
        .ex_mem_pc           (ex_mem_pc),
        .ex_mem_pc_plus4     (ex_mem_pc_plus4),
        .ex_mem_instr        (ex_mem_instr),
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
        .ex_mem_csr          (ex_mem_csr),
        .ex_mem_csr_addr     (ex_mem_csr_addr),
        .ex_mem_csr_op       (ex_mem_csr_op),
        .ex_mem_csr_src_data (ex_mem_csr_src_data),
        .ex_mem_csr_wen      (ex_mem_csr_wen)
    );

    // ========================================================================
    // MEM
    // ========================================================================
    mem_stage u_mem_stage (
        .clk                  (clk),
        .rst_n                (rst_n),
        .ex_mem_valid         (ex_mem_valid),
        .ex_mem_pc            (ex_mem_pc),
        .ex_mem_pc_plus4      (ex_mem_pc_plus4),
        .ex_mem_instr         (ex_mem_instr),
        .ex_mem_alu_result    (ex_mem_alu_result),
        .ex_mem_store_data    (ex_mem_store_data),
        .ex_mem_rd_addr       (ex_mem_rd_addr),
        .ex_mem_imm           (ex_mem_imm),
        .ex_mem_wb_en         (ex_mem_wb_en),
        .ex_mem_wb_src        (ex_mem_wb_src),
        .ex_mem_mem_read      (ex_mem_mem_read),
        .ex_mem_mem_write     (ex_mem_mem_write),
        .ex_mem_mem_size      (ex_mem_mem_size),
        .ex_mem_mem_unsigned  (ex_mem_mem_unsigned),
        .ex_mem_is_load       (ex_mem_is_load),
        .ex_mem_is_store      (ex_mem_is_store),
        .ex_mem_illegal       (ex_mem_illegal),
        .ex_mem_csr           (ex_mem_csr),
        .ex_mem_csr_addr      (ex_mem_csr_addr),
        .ex_mem_csr_op        (ex_mem_csr_op),
        .ex_mem_csr_src_data  (ex_mem_csr_src_data),
        .ex_mem_csr_wen       (ex_mem_csr_wen),
        .csr_rdata            (csr_rdata),
        .csr_implemented      (csr_implemented),
        .csr_we               (mem_csr_we),
        .csr_waddr            (mem_csr_waddr),
        .csr_wdata            (mem_csr_wdata),
        .mem_rdata            (mem_rdata),
        .mem_addr             (mem_addr),
        .mem_wdata            (mem_wdata),
        .mem_wmask            (mem_wmask),
        .mem_ren              (mem_ren),
        .mem_wen              (mem_wen),
        .mem_trap             (mem_trap),
        .mem_trap_cause       (mem_trap_cause),
        .mem_trap_tval        (mem_trap_tval),
        .mem_wb_valid         (mem_wb_valid),
        .mem_wb_wb_en         (mem_wb_wb_en),
        .mem_wb_rd_addr       (mem_wb_rd_addr),
        .mem_wb_wb_data       (mem_wb_wb_data)
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
    // CSR file
    // ========================================================================
    csr_file u_csr_file (
        .clk             (clk),
        .rst_n           (rst_n),
        .csr_addr        (ex_mem_csr_addr),
        .csr_rdata       (csr_rdata),
        .csr_implemented (csr_implemented),
        .csr_we          (mem_csr_we),
        .csr_waddr       (mem_csr_waddr),
        .csr_wdata       (mem_csr_wdata),
        .trap            (trap_taken),
        .trap_pc         (trap_pc_w),
        .trap_cause      (trap_cause_w),
        .trap_tval       (trap_tval_w),
        .mret            (ex_mret_commit),
        .retire          (retire),
        .mepc_o          (mepc_o),
        .mstatus_o       (mstatus_o),
        .mtvec_o         (mtvec_o)
    );

endmodule
