`include "../../riscv_def.vh"

// ============================================================================
//  wb_stage
//
//  流水线第 6 级：把 MEM/WB 中的结果写回寄存器堆。
//
//  本模块是纯组合逻辑，MEM/WB 寄存器就是它的输入边界。
//  写使能在这里统一做最后门控：
//    - 指令有效
//    - 指令确实要写回
//    - rd != x0
// ============================================================================
module wb_stage (
    input  wire        mem_wb_valid,
    input  wire        mem_wb_wb_en,
    input  wire [4:0]  mem_wb_rd_addr,
    input  wire [31:0] mem_wb_wb_data,

    output wire        wb_wen,
    output wire [4:0]  wb_waddr,
    output wire [31:0] wb_wdata
);

    assign wb_wen   = mem_wb_valid && mem_wb_wb_en && (mem_wb_rd_addr != 5'd0);
    assign wb_waddr = mem_wb_rd_addr;
    assign wb_wdata = mem_wb_wb_data;

endmodule
