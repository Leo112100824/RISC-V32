`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_mem_stage;
 reg clk=0,rst_n=0,valid=0;always #5 clk=~clk;
 reg [31:0] pc=0,pc4=0,instr=0,alu=0,storedata=0,imm=0,csrdata=0,memdata=0;reg [4:0] rd=0;reg [2:0] wb_src=0;reg [1:0] size=0,csrop=0;reg [11:0] csraddr=0;reg wben=0,memrd=0,memwr=0,unsigned_load=0,isload=0,isstore=0,illegal=0,csr=0,csrw=0,implemented=1;
 wire csrwe,memtrap,ren,wen;wire [11:0] csrwa;wire [31:0] csrwd,memaddr,memwdata,tval;wire [3:0] mask,cause;wire wbvalid,wbwen;wire [4:0] wbrd;wire [31:0] wbdata;
 mem_stage dut(.clk(clk),.rst_n(rst_n),.ex_mem_valid(valid),.ex_mem_pc(pc),.ex_mem_pc_plus4(pc4),.ex_mem_instr(instr),.ex_mem_alu_result(alu),.ex_mem_store_data(storedata),.ex_mem_rd_addr(rd),.ex_mem_imm(imm),.ex_mem_wb_en(wben),.ex_mem_wb_src(wb_src),.ex_mem_mem_read(memrd),.ex_mem_mem_write(memwr),.ex_mem_mem_size(size),.ex_mem_mem_unsigned(unsigned_load),.ex_mem_is_load(isload),.ex_mem_is_store(isstore),.ex_mem_illegal(illegal),.ex_mem_csr(csr),.ex_mem_csr_addr(csraddr),.ex_mem_csr_op(csrop),.ex_mem_csr_src_data(storedata),.ex_mem_csr_wen(csrw),.csr_rdata(csrdata),.csr_implemented(implemented),.csr_we(csrwe),.csr_waddr(csrwa),.csr_wdata(csrwd),.mem_rdata(memdata),.mem_addr(memaddr),.mem_wdata(memwdata),.mem_wmask(mask),.mem_ren(ren),.mem_wen(wen),.mem_trap(memtrap),.mem_trap_cause(cause),.mem_trap_tval(tval),.mem_wb_valid(wbvalid),.mem_wb_wb_en(wbwen),.mem_wb_rd_addr(wbrd),.mem_wb_wb_data(wbdata));
 integer checks=0;
 task ck(input logic ok,input string label_text);
 begin if(ok!==1'b1)$fatal(1,"MEM: %s",label_text);checks++;end endtask
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 initial begin
   @(negedge clk);ck(wbvalid===0 && wbwen===0,"reset");rst_n=1;
   valid=1;wben=1;rd=9;wb_src=`WB_ALU;alu=32'h55;tick();
   ck(wbvalid && wbwen && wbrd===9 && wbdata===32'h55,"ALU writeback");
   pc4=32'h104;wb_src=`WB_PC4;tick();ck(wbdata===32'h104,"PC+4 writeback");
   imm=32'h12345000;wb_src=`WB_IMM;tick();ck(wbdata===imm,"IMM writeback");
   csrdata=32'hff;wb_src=`WB_CSR;csr=1;csraddr=`CSR_MSCRATCH;csrw=1;storedata=32'h50;csrop=`CSR_OP_WRITE;#1;
   ck(csrwe && csrwd===32'h50 && csrwa===`CSR_MSCRATCH,"CSRRW source/address");tick();
   ck(wbdata===32'hff,"CSR returns old value");
   csrop=`CSR_OP_CLEAR;#1;ck(csrwd===32'haf,"CSRRC mask");
   csrop=`CSR_OP_SET;storedata=32'h100;#1;ck(csrwd===32'h1ff,"CSRRS mask");
   csrw=0;csraddr=`CSR_MHARTID;#1;ck(!memtrap && !csrwe,"read-only CSR pure read allowed");
   csrw=1;instr=32'hf1419073;#1;ck(memtrap && cause===`EXC_ILLEGAL_INSTR && tval===instr && !csrwe,"read-only CSR write trapped");
   tick();ck(!wbvalid && !wbwen,"CSR exception suppresses writeback");
   csraddr=12'h7c0;implemented=0;csrw=0;#1;ck(memtrap && !csrwe,"unimplemented CSR pure read trapped");
   csr=0;implemented=1;memrd=1;size=`MEM_WORD;alu=32'h102;#1;
   ck(memtrap && cause===`EXC_LOAD_MISALIGNED && tval===alu && !ren,"word load alignment");
   tick();ck(!wbvalid && !wbwen,"load exception suppresses writeback");
   size=`MEM_HALF;alu=32'h101;#1;ck(memtrap && !ren,"halfword load alignment");
   memrd=0;memwr=1;#1;ck(memtrap && cause===`EXC_STORE_MISALIGNED && !wen && mask===0,"store trap suppresses all byte lanes");
   alu=32'h100;size=`MEM_WORD;storedata=32'h12345678;#1;ck(!memtrap && wen && mask===4'hf && memwdata===storedata,"aligned store");
   memwr=0;memrd=1;memdata=32'h89abcdef;wb_src=`WB_MEM;tick();ck(wbdata===memdata && ren,"aligned load writeback");
   valid=0;csr=1;csrw=1;#1;ck(!memtrap && !csrwe && !ren && !wen,"bubble has no memory/CSR effects");
   tick();ck(!wbvalid && !wbwen,"bubble is not retired");
   $display("PASS tb_mem_stage %0d checks",checks);$finish;
 end
 initial begin #5000;$fatal(1,"tb_mem_stage watchdog");end
endmodule
