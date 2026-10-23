`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_ex_stage;
 reg clk=0,rst_n=0,valid=0;always #5 clk=~clk;
 reg [31:0] pc=0,instr=0,a=0,b=0,imm=0,memwb_data=0,mepc=0;
 reg [4:0] rs1=0,rs2=0,rd=0,memwb_rd=0;reg wb_en=0;reg [2:0] wb_src=0;reg [1:0] src1=0,src2=0,size=0;reg [3:0] aluop=0,brtype=0;
 reg memrd=0,memwr=0,uns=0,branch=0,isload=0,isstore=0,jal=0,jalr=0,illegal=0,csr=0,csrw=0,ecall=0,ebreak=0,mret=0,fence=0,fencei=0,memtrap=0,memwb_valid=0,memwb_wen=0;
 reg [11:0] csraddr=0;reg [1:0] csrop=0;wire redirect,trap,mret_commit;wire [31:0] redirect_pc,tval;wire [3:0] cause;wire exmem_valid,exmem_wben;wire [31:0] result;wire [4:0] exmem_rd;
 integer checks=0;
 ex_stage dut(.clk(clk),.rst_n(rst_n),.id_ex_valid(valid),.id_ex_pc(pc),.id_ex_instr(instr),.id_ex_rs1_data(a),.id_ex_rs2_data(b),.id_ex_rs1_addr(rs1),.id_ex_rs2_addr(rs2),.id_ex_rd_addr(rd),.id_ex_imm(imm),.id_ex_wb_en(wb_en),.id_ex_wb_src(wb_src),.id_ex_alu_src1(src1),.id_ex_alu_src2(src2),.id_ex_alu_op(aluop),.id_ex_mem_read(memrd),.id_ex_mem_write(memwr),.id_ex_mem_size(size),.id_ex_mem_unsigned(uns),.id_ex_branch(branch),.id_ex_branch_type(brtype),.id_ex_is_load(isload),.id_ex_is_store(isstore),.id_ex_is_jal(jal),.id_ex_is_jalr(jalr),.id_ex_illegal(illegal),.id_ex_csr(csr),.id_ex_csr_addr(csraddr),.id_ex_csr_op(csrop),.id_ex_csr_src_is_imm(1'b0),.id_ex_csr_wen(csrw),.id_ex_ecall(ecall),.id_ex_ebreak(ebreak),.id_ex_mret(mret),.id_ex_fence(fence),.id_ex_fence_i(fencei),.mem_wb_wb_data(memwb_data),.mem_wb_valid(memwb_valid),.mem_wb_wb_en(memwb_wen),.mem_wb_rd_addr(memwb_rd),.mem_trap(memtrap),.mepc_i(mepc),.ex_redirect(redirect),.ex_redirect_pc(redirect_pc),.ex_trap(trap),.ex_trap_cause(cause),.ex_trap_tval(tval),.ex_mret_commit(mret_commit),.ex_mem_valid(exmem_valid),.ex_mem_alu_result(result),.ex_mem_rd_addr(exmem_rd),.ex_mem_wb_en(exmem_wben),
        .ex_mem_pc(), .ex_mem_pc_plus4(), .ex_mem_instr(), .ex_mem_store_data(), .ex_mem_imm(), .ex_mem_wb_src(), .ex_mem_mem_read(), .ex_mem_mem_write(), .ex_mem_mem_size(), .ex_mem_mem_unsigned(), .ex_mem_is_load(), .ex_mem_is_store(), .ex_mem_illegal(), .ex_mem_csr(), .ex_mem_csr_addr(), .ex_mem_csr_op(), .ex_mem_csr_src_data(), .ex_mem_csr_wen());
 task ck(input logic ok,input string label_text);
 begin if(ok!==1'b1)$fatal(1,"EX: %s",label_text);checks++;end endtask
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task defaults;
 begin
   valid=1;pc=32'h100;instr=`NOP;a=0;b=0;imm=0;rd=0;rs1=0;rs2=0;
   wb_en=0;wb_src=`WB_ALU;src1=`ALUSRC1_RS1;src2=`ALUSRC2_RS2;aluop=`ALU_ADD;
   branch=0;brtype=`BR_BEQ;jal=0;jalr=0;illegal=0;ecall=0;ebreak=0;mret=0;fence=0;fencei=0;
   memrd=0;memwr=0;csr=0;csrw=0;memtrap=0;memwb_valid=0;memwb_wen=0;
 end endtask
 initial begin
   @(negedge clk);ck(exmem_valid===0,"reset");rst_n=1;defaults();
   a=4;b=6;rd=3;wb_en=1;tick();
   ck(exmem_valid && result===10 && exmem_rd===3 && exmem_wben,"ALU/register boundary");
   defaults();wb_en=1;wb_src=`WB_IMM;rd=5;imm=32'h12345000;tick();
   defaults();rs1=5;a=32'hbad;b=1;rd=6;tick();ck(result===32'h12345001,"LUI IMM forwarding");
   defaults();jal=1;imm=32'h40;rd=1;wb_en=1;wb_src=`WB_PC4;#1;
   ck(redirect && redirect_pc===32'h140 && !trap,"JAL target");tick();
   defaults();rs1=1;a=32'hbad;b=2;tick();ck(result===32'h106,"JAL PC+4 forwarding");
   defaults();valid=0;tick();defaults();rs1=7;memwb_valid=1;memwb_wen=1;memwb_rd=7;memwb_data=32'h77;b=2;tick();
   ck(result===32'h79,"MEM/WB forwarding");
   defaults();branch=1;a=3;b=3;imm=32'h20;#1;ck(redirect && redirect_pc===32'h120,"taken branch");
   b=4;imm=2;#1;ck(!redirect && !trap,"not-taken misaligned target does not trap");
   b=3;#1;ck(trap && cause===`EXC_INST_MISALIGNED && tval===32'h102 && !redirect,"taken branch alignment");tick();
   ck(!exmem_valid && !exmem_wben,"faulting branch suppressed");
   defaults();jalr=1;src2=`ALUSRC2_IMM;a=32'h201;#1;ck(redirect && redirect_pc===32'h200 && !trap,"JALR clears bit zero");
   a=32'h203;#1;ck(trap && cause===`EXC_INST_MISALIGNED && tval===32'h202,"JALR bit one alignment");
   defaults();ecall=1;#1;ck(trap && cause===`EXC_ECALL_M && tval===0,"ECALL");
   defaults();ebreak=1;#1;ck(trap && cause===`EXC_BREAKPOINT && tval===0,"EBREAK");
   defaults();illegal=1;instr=32'hffffffff;wb_en=1;#1;ck(trap && cause===`EXC_ILLEGAL_INSTR && tval===instr,"illegal instruction payload");
   tick();ck(!exmem_valid && !exmem_wben,"illegal instruction writeback suppressed");
   defaults();mret=1;mepc=32'h400;#1;ck(redirect && mret_commit && redirect_pc===32'h400,"MRET target/commit");
   memtrap=1;#1;ck(!redirect && !mret_commit,"older MEM trap suppresses MRET");tick();ck(!exmem_valid,"MEM trap kills younger EX");
   defaults();fencei=1;#1;ck(redirect && redirect_pc===32'h104,"FENCE.I refetch");
   valid=0;#1;ck(!redirect && !trap && !mret_commit,"invalid instruction has no control effect");
   $display("PASS tb_ex_stage %0d checks",checks);$finish;
 end
 initial begin #5000;$fatal(1,"tb_ex_stage watchdog");end
endmodule
