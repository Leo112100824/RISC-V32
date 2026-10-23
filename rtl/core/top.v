`include "../riscv_def.vh"

// ============================================================================
//  top
//
//  顶层只负责把 rv32_core（六级流水线小顶层）与外部存储器接口连接起来。
//
//  接口约定：
//    - imem：同步读，imem_addr 给出后下一拍 imem_rdata 有效
//    - dmem：组合读，同步字节写（mem_wmask）
// ============================================================================
module top (
    input  wire                 clk,
    input  wire                 rst_n,

    output wire [`XLEN-1:0]     imem_addr,
    input  wire [`XLEN-1:0]     imem_rdata,

    output wire [`XLEN-1:0]     mem_addr,
    output wire [`XLEN-1:0]     mem_wdata,
    output wire [3:0]           mem_wmask,
    output wire                 mem_ren,
    output wire                 mem_wen,
    input  wire [`XLEN-1:0]     mem_rdata,

    // Trap observability
    output wire                 trap,
    output wire [3:0]           trap_cause,
    output wire [`XLEN-1:0]     trap_pc,
    output wire [`XLEN-1:0]     trap_tval
);

    rv32_core u_rv32_core (
        .clk           (clk),
        .rst_n         (rst_n),
        .imem_addr     (imem_addr),
        .imem_rdata    (imem_rdata),
        .mem_addr      (mem_addr),
        .mem_wdata     (mem_wdata),
        .mem_wmask     (mem_wmask),
        .mem_ren       (mem_ren),
        .mem_wen       (mem_wen),
        .mem_rdata     (mem_rdata),
        .trap          (trap),
        .trap_cause    (trap_cause),
        .trap_pc       (trap_pc),
        .trap_tval     (trap_tval)
    );

endmodule
