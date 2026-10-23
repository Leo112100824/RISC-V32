`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_decoder;
 reg [31:0] ins;wire [4:0] rs1,rs2,rd;wire ru1,ru2,illegal,wen,mr,mw,load,store,csr,ecall;wire [31:0] imm;integer n=0;
 decoder dut(.instr(ins),.rs1_addr(rs1),.rs2_addr(rs2),.rd_addr(rd),.rs1_used(ru1),.rs2_used(ru2),.imm(imm),.illegal(illegal),.wb_en(wen),.mem_read(mr),.mem_write(mw),.is_load(load),.is_store(store),.csr(csr),.ecall(ecall),
        .system_instr(), .wb_src(), .alu_src1(), .alu_src2(), .alu_op(), .mem_size(), .mem_unsigned(), .branch(), .branch_type(), .pc_src(), .is_branch(), .is_jal(), .is_jalr(), .csr_addr(), .csr_op(), .csr_src_is_imm(), .csr_wen(), .ebreak(), .mret(), .fence(), .fence_i());
 initial begin ins=32'h00508113;#1;if(illegal||!wen||!ru1||rd!=2||rs1!=1||imm!=5)$fatal(1,"ADDI decode");n=n+1;ins=32'h0000a183;#1;if(illegal||!load||!mr||mw)$fatal(1,"LW decode");n=n+1;ins=32'h0020a023;#1;if(illegal||!store||!mw||wen)$fatal(1,"SW decode");n=n+1;ins=32'h300091f3;#1;if(illegal||!csr||!wen)$fatal(1,"CSR decode");n=n+1;ins=32'h00000073;#1;if(illegal||!ecall)$fatal(1,"ECALL decode");n=n+1;ins=32'hffffffff;#1;if(!illegal||wen||mr||mw)$fatal(1,"illegal side effects");n=n+1;$display("PASS tb_decoder %0d checks",n);$finish;end
endmodule
