`include "../../riscv_def.vh"

// ============================================================================
//  mem_stage
//
//  流水线第 5 级：访存（LSU）+ 写回数据选择 + MEM/WB 流水线寄存器。
//
//  数据存储器接口沿用当前单周期版本的约定：组合读、同步字节写。
//  若后续换成同步读 BRAM，需要在 MEM 级增加 mem_ready 握手并停顿，
//  这属于 SoC 集成阶段的工作。
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
    // MEM/WB pipeline register
    // ------------------------------------------------------------------
    output reg         mem_wb_valid,
    output reg         mem_wb_wb_en,
    output reg  [4:0]  mem_wb_rd_addr,
    output reg  [31:0] mem_wb_wb_data
);

    // ------------------------------------------------------------------
    // LSU
    // ------------------------------------------------------------------
    wire [31:0] load_data;
    wire        mem_read_en;
    wire        mem_write_en;

    assign mem_read_en  = ex_mem_valid && ex_mem_mem_read  && !ex_mem_illegal;
    assign mem_write_en = ex_mem_valid && ex_mem_mem_write && !ex_mem_illegal;

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
            mem_wb_valid   <= ex_mem_valid;
            mem_wb_wb_en   <= ex_mem_valid && ex_mem_wb_en && !ex_mem_illegal;
            mem_wb_rd_addr <= ex_mem_rd_addr;
            mem_wb_wb_data <= wb_data_next;
        end
    end

endmodule
