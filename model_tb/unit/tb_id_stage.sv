`timescale 1ns/1ps
module tb_id_stage;
 reg clk=0,rst_n=0,stall=0,flush=0,if2_valid=0,wb_wen=0;always #5 clk=~clk;
 reg [31:0] if2_instr=0,if2_pc=0,wb_wdata=0;reg [4:0] wb_waddr=0;
 wire id_ex_valid;wire [31:0] id_ex_rs1_data,id_ex_imm;wire [4:0] id_ex_rd_addr;integer n=0;
 id_stage dut(.clk(clk),.rst_n(rst_n),.stall(stall),.flush(flush),.if2_instr(if2_instr),.if2_pc(if2_pc),.if2_valid(if2_valid),.wb_wen(wb_wen),.wb_waddr(wb_waddr),.wb_wdata(wb_wdata),.id_ex_valid(id_ex_valid),.id_ex_rs1_data(id_ex_rs1_data),.id_ex_imm(id_ex_imm),.id_ex_rd_addr(id_ex_rd_addr),
        .id_rs1_addr(), .id_rs2_addr(), .id_rs1_used(), .id_rs2_used(), .id_valid(), .id_illegal(), .id_ex_pc(), .id_ex_instr(), .id_ex_rs2_data(), .id_ex_rs1_addr(), .id_ex_rs2_addr(), .id_ex_wb_en(), .id_ex_wb_src(), .id_ex_alu_src1(), .id_ex_alu_src2(), .id_ex_alu_op(), .id_ex_mem_read(), .id_ex_mem_write(), .id_ex_mem_size(), .id_ex_mem_unsigned(), .id_ex_branch(), .id_ex_branch_type(), .id_ex_pc_src(), .id_ex_is_load(), .id_ex_is_store(), .id_ex_is_jal(), .id_ex_is_jalr(), .id_ex_illegal(), .id_ex_csr(), .id_ex_csr_addr(), .id_ex_csr_op(), .id_ex_csr_src_is_imm(), .id_ex_csr_wen(), .id_ex_ecall(), .id_ex_ebreak(), .id_ex_mret(), .id_ex_fence(), .id_ex_fence_i());
 initial begin @(negedge clk);rst_n=1;if2_instr=32'h00500293;if2_pc=32'h100;if2_valid=1;@(negedge clk);if(!id_ex_valid||id_ex_rd_addr!=5||id_ex_imm!=5)$fatal(1,"ID ADDI decode/latch");n=n+1;
 if2_instr=32'h00128313;if2_pc=32'h104;wb_wen=1;wb_waddr=5;wb_wdata=7;@(negedge clk);wb_wen=0;if(!id_ex_valid||id_ex_rd_addr!=6||id_ex_rs1_data!=7)$fatal(1,"ID register read/forward");n=n+1;
 flush=1;@(negedge clk);flush=0;if(id_ex_valid)$fatal(1,"ID flush");n=n+1;$display("PASS tb_id_stage %0d checks",n);$finish;end
endmodule
