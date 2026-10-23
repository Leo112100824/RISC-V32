`include "../../riscv_def.vh"

// ============================================================================
//  forward_unit
//
//  EX 级操作数前递选择：
//    0 : 使用 ID/EX 中锁存的寄存器值
//    1 : 使用 EX/MEM 的最终写回值（ALU / PC+4 / IMM）
//    2 : 使用 MEM/WB 的写回数据
//
//  优先级：EX/MEM 比 MEM/WB 更新，必须优先。
//  load 与 CSR 读在 EX/MEM 时不能前递：
//    - load 的 alu_result 是地址，数据要到 MEM/WB 才有效
//    - CSR 的读值要到 MEM 级才产生
//  由 hazard_unit 保证紧邻的消费者停顿 1 拍，随后从 MEM/WB 前递。
// ============================================================================
module forward_unit (
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,

    // EX/MEM
    input  wire        ex_mem_valid,
    input  wire        ex_mem_wb_en,
    input  wire        ex_mem_is_load,
    input  wire        ex_mem_is_csr,
    input  wire [4:0]  ex_mem_rd_addr,

    // MEM/WB
    input  wire        mem_wb_valid,
    input  wire        mem_wb_wb_en,
    input  wire [4:0]  mem_wb_rd_addr,

    output reg  [1:0]  fwd_a,
    output reg  [1:0]  fwd_b
);

    always @(*) begin
        fwd_a = 2'd0;
        fwd_b = 2'd0;

        // EX/MEM：最终写回值，不能是 load / CSR
        if (ex_mem_valid && ex_mem_wb_en && !ex_mem_is_load && !ex_mem_is_csr &&
            (ex_mem_rd_addr != 5'd0)) begin
            if (rs1_addr == ex_mem_rd_addr) fwd_a = 2'd1;
            if (rs2_addr == ex_mem_rd_addr) fwd_b = 2'd1;
        end

        // MEM/WB：最终写回值，优先级低于 EX/MEM
        if (mem_wb_valid && mem_wb_wb_en && (mem_wb_rd_addr != 5'd0)) begin
            if ((fwd_a != 2'd1) && (rs1_addr == mem_wb_rd_addr)) fwd_a = 2'd2;
            if ((fwd_b != 2'd1) && (rs2_addr == mem_wb_rd_addr)) fwd_b = 2'd2;
        end
    end

endmodule
