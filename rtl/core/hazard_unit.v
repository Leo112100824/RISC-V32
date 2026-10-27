`include "../riscv_def.vh"

// ============================================================================
//  hazard_unit
//
//  当前只处理 load-use 数据冒险：
//    EX 级是 load，ID 级指令要读它的 rd -> 停顿 1 拍。
//
//  分支/跳转的重定向由 EX 直接产生，不需要本模块产生 flush；
//  core 会把 redirect 同时送给 IF 与 ID/EX。
//
//  注意：
//    - rd = x0 不产生冒险。
//    - 只有 ID 指令真的使用 rs1/rs2 时才停顿（LUI/JAL 等不会误停）。
//    - 非法指令不产生停顿。
// ============================================================================
module hazard_unit (
    // EX 级（ID/EX 寄存器）中的指令
    input  wire        id_ex_valid,
    input  wire        id_ex_mem_read,
    input  wire        id_ex_csr,
    input  wire        id_ex_wb_en,
    input  wire [4:0]  id_ex_rd_addr,

    // ID 级（IF/ID 边界）中的指令
    input  wire        id_valid,
    input  wire        id_illegal,
    input  wire        id_rs1_used,
    input  wire        id_rs2_used,
    input  wire [4:0]  id_rs1_addr,
    input  wire [4:0]  id_rs2_addr,

    output wire        stall
);

    wire load_in_ex;
    wire csr_in_ex;
    wire rd_nonzero;
    wire uses_rs1;
    wire uses_rs2;
    wire raw_rs1;
    wire raw_rs2;

    assign load_in_ex = id_ex_valid && id_ex_mem_read;
    assign csr_in_ex  = id_ex_valid && id_ex_csr && id_ex_wb_en;
    assign rd_nonzero = (id_ex_rd_addr != 5'd0);
    assign uses_rs1   = id_valid && !id_illegal && id_rs1_used;
    assign uses_rs2   = id_valid && !id_illegal && id_rs2_used;
    assign raw_rs1    = uses_rs1 && (id_rs1_addr == id_ex_rd_addr);
    assign raw_rs2    = uses_rs2 && (id_rs2_addr == id_ex_rd_addr);

    // load 与 CSR 读都要等结果进入 MEM/WB 后才能前递
    assign stall = (load_in_ex || csr_in_ex) && rd_nonzero && (raw_rs1 || raw_rs2);

endmodule
