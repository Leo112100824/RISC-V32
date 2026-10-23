`include "../../riscv_def.vh"

// ============================================================================
//  mem_stage
//
//  流水线第 5 级：访存（LSU）+ CSR 读写 + 异常检测 + 写回数据选择 +
//  MEM/WB 流水线寄存器。
//
//  MEM 级异常：
//    - load / store 地址非对齐（cause 4 / 6）
//    - CSR 地址未实现（cause 2）
//    - 写只读 CSR（地址高 2 位为 2'b11，cause 2）
//
//  MEM 级异常优先级高于 EX；异常指令不写回、不写存储器、不写 CSR。
// ============================================================================
module mem_stage (
    input  wire        clk,
    input  wire        rst_n,

    // ------------------------------------------------------------------
    // EX/MEM
    // ------------------------------------------------------------------
    input  wire        ex_mem_valid,
    input  wire [31:0] ex_mem_pc,
    input  wire [31:0] ex_mem_pc_plus4,
    input  wire [31:0] ex_mem_instr,
    input  wire [31:0] ex_mem_alu_result,
    input  wire [31:0] ex_mem_store_data,
    input  wire [4:0]  ex_mem_rd_addr,
    input  wire [31:0] ex_mem_imm,
    input  wire        ex_mem_wb_en,
    input  wire [2:0]  ex_mem_wb_src,
    input  wire        ex_mem_mem_read,
    input  wire        ex_mem_mem_write,
    input  wire [1:0]  ex_mem_mem_size,
    input  wire        ex_mem_mem_unsigned,
    input  wire        ex_mem_is_load,
    input  wire        ex_mem_is_store,
    input  wire        ex_mem_illegal,

    input  wire        ex_mem_csr,
    input  wire [11:0] ex_mem_csr_addr,
    input  wire [1:0]  ex_mem_csr_op,
    input  wire [31:0] ex_mem_csr_src_data,
    input  wire        ex_mem_csr_wen,

    // ------------------------------------------------------------------
    // CSR file
    // ------------------------------------------------------------------
    input  wire [31:0] csr_rdata,
    input  wire        csr_implemented,
    output wire        csr_we,
    output wire [11:0] csr_waddr,
    output wire [31:0] csr_wdata,

    // ------------------------------------------------------------------
    // Data memory
    // ------------------------------------------------------------------
    input  wire [31:0] mem_rdata,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_wmask,
    output wire        mem_ren,
    output wire        mem_wen,

    // ------------------------------------------------------------------
    // MEM 级异常
    // ------------------------------------------------------------------
    output wire        mem_trap,
    output wire [3:0]  mem_trap_cause,
    output wire [31:0] mem_trap_tval,

    // ------------------------------------------------------------------
    // MEM/WB pipeline register
    // ------------------------------------------------------------------
    output reg         mem_wb_valid,
    output reg         mem_wb_wb_en,
    output reg  [4:0]  mem_wb_rd_addr,
    output reg  [31:0] mem_wb_wb_data
);

    // ------------------------------------------------------------------
    // CSR write data / protection
    // ------------------------------------------------------------------
    reg [31:0] csr_wdata_calc;

    always @(*) begin
        case (ex_mem_csr_op)
            `CSR_OP_WRITE: csr_wdata_calc = ex_mem_csr_src_data;
            `CSR_OP_SET:   csr_wdata_calc = csr_rdata | ex_mem_csr_src_data;
            `CSR_OP_CLEAR: csr_wdata_calc = csr_rdata & ~ex_mem_csr_src_data;
            default:       csr_wdata_calc = csr_rdata;
        endcase
    end

    wire csr_bad_addr;
    wire csr_readonly;
    wire csr_exception;

    assign csr_bad_addr  = ex_mem_csr && !csr_implemented;
    assign csr_readonly  = ex_mem_csr && ex_mem_csr_wen &&
                           (ex_mem_csr_addr[11:10] == 2'b11);
    assign csr_exception = ex_mem_valid && (csr_bad_addr || csr_readonly);

    assign csr_we    = ex_mem_valid && ex_mem_csr && ex_mem_csr_wen &&
                       !csr_bad_addr && !csr_readonly;
    assign csr_waddr = ex_mem_csr_addr;
    assign csr_wdata = csr_wdata_calc;

    // ------------------------------------------------------------------
    // Misaligned detection
    // ------------------------------------------------------------------
    wire misaligned;
    wire load_misaligned;
    wire store_misaligned;

    assign misaligned = (ex_mem_mem_size == `MEM_WORD) ? (ex_mem_alu_result[1:0] != 2'b00) :
                        (ex_mem_mem_size == `MEM_HALF) ? ex_mem_alu_result[0] :
                                                         1'b0;

    assign load_misaligned  = ex_mem_valid && ex_mem_mem_read  &&
                              !ex_mem_illegal && misaligned;
    assign store_misaligned = ex_mem_valid && ex_mem_mem_write &&
                              !ex_mem_illegal && misaligned;

    assign mem_trap       = load_misaligned || store_misaligned || csr_exception;
    assign mem_trap_cause = load_misaligned  ? `EXC_LOAD_MISALIGNED  :
                            store_misaligned ? `EXC_STORE_MISALIGNED :
                                                `EXC_ILLEGAL_INSTR;
    assign mem_trap_tval  = (load_misaligned || store_misaligned) ? ex_mem_alu_result
                                                                  : ex_mem_instr;

    // ------------------------------------------------------------------
    // LSU
    // ------------------------------------------------------------------
    wire [31:0] load_data;
    wire        mem_read_en;
    wire        mem_write_en;

    assign mem_read_en  = ex_mem_valid && ex_mem_mem_read  && !ex_mem_illegal && !mem_trap;
    assign mem_write_en = ex_mem_valid && ex_mem_mem_write && !ex_mem_illegal && !mem_trap;

    lsu u_lsu (
        .addr         (ex_mem_alu_result),
        .rs2_data     (ex_mem_store_data),
        .mem_rd_en    (mem_read_en),
        .mem_wr_en    (mem_write_en),
        .mem_size     (ex_mem_mem_size),
        .mem_unsigned (ex_mem_mem_unsigned),
        .mem_rdata    (mem_rdata),
        .mem_addr     (mem_addr),
        .mem_wdata    (mem_wdata),
        .mem_wmask    (mem_wmask),
        .mem_ren      (mem_ren),
        .mem_wen      (mem_wen),
        .load_data    (load_data)
    );

    // ------------------------------------------------------------------
    // Write-back data selection
    // ------------------------------------------------------------------
    reg [31:0] wb_data_next;

    always @(*) begin
        case (ex_mem_wb_src)
            `WB_ALU: wb_data_next = ex_mem_alu_result;
            `WB_MEM: wb_data_next = load_data;
            `WB_PC4: wb_data_next = ex_mem_pc_plus4;
            `WB_IMM: wb_data_next = ex_mem_imm;
            `WB_CSR: wb_data_next = csr_rdata;
            default: wb_data_next = 32'd0;
        endcase
    end

    // ------------------------------------------------------------------
    // MEM/WB pipeline register
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_valid   <= 1'b0;
            mem_wb_wb_en   <= 1'b0;
            mem_wb_rd_addr <= 5'd0;
            mem_wb_wb_data <= 32'd0;
        end else begin
            mem_wb_valid   <= ex_mem_valid && !mem_trap;
            mem_wb_wb_en   <= ex_mem_valid && ex_mem_wb_en && !mem_trap;
            mem_wb_rd_addr <= ex_mem_rd_addr;
            mem_wb_wb_data <= wb_data_next;
        end
    end

endmodule
