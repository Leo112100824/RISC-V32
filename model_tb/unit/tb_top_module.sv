`timescale 1ns/1ps
module tb_top_module;
 localparam BENCH_NAME="tb_top_module";
 `include "core_test_env.vh"
 assign trap_overlap=dut.u_rv32_core.mem_trap && dut.u_rv32_core.ex_trap;
 top dut(.clk(clk),.rst_n(rst_n),.imem_addr(imem_addr),.imem_rdata(imem_rdata),.mem_addr(mem_addr),.mem_wdata(mem_wdata),.mem_wmask(mem_wmask),.mem_ren(mem_ren),.mem_wen(mem_wen),.mem_rdata(mem_rdata),.trap(trap),.trap_cause(tcause),.trap_pc(tpc),.trap_tval(ttv));
endmodule
