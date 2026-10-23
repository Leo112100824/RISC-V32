`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_lsu;
 reg [31:0] addr,rs2,rdata;reg ren,wen,uns;reg [1:0] size;wire [31:0] maddr,wdata,load;wire [3:0] mask;wire mr,mw;integer n=0;
 lsu dut(.addr(addr),.rs2_data(rs2),.mem_rd_en(ren),.mem_wr_en(wen),.mem_size(size),.mem_unsigned(uns),.mem_rdata(rdata),.mem_addr(maddr),.mem_wdata(wdata),.mem_wmask(mask),.mem_ren(mr),.mem_wen(mw),.load_data(load));
 task ck(input [3:0] mk,input [31:0] wd);begin #1;if(mask!==mk||wdata!==wd)$fatal(1,"store got mask=%b data=%h expected=%b/%h",mask,wdata,mk,wd);n=n+1;end endtask
 initial begin addr=32'h101;rs2=32'h12345678;rdata=32'h80ff7f01;ren=0;wen=1;size=`MEM_BYTE;ck(2,32'h00007800);addr=32'h102;ck(4,32'h00780000);addr=32'h100;size=`MEM_HALF;ck(3,32'h00005678);addr=32'h102;ck(12,32'h56780000);addr=32'h100;size=`MEM_WORD;ck(15,rs2);wen=0;ren=1;size=`MEM_BYTE;uns=0;addr=32'h100;#1;if(load!==1)$fatal(1,"LB lane0");addr=32'h101;#1;if(load!==32'h7f)$fatal(1,"LB lane1");addr=32'h102;#1;if(load!==32'hffffffff)$fatal(1,"LB sign");uns=1;#1;if(load!==32'hff)$fatal(1,"LBU");size=`MEM_HALF;addr=32'h102;uns=0;#1;if(load!==32'hffff80ff)$fatal(1,"LH sign");uns=1;#1;if(load!==32'h80ff)$fatal(1,"LHU");size=`MEM_WORD;addr=32'h100;#1;if(load!==rdata)$fatal(1,"LW");n=n+7;$display("PASS tb_lsu %0d checks",n);$finish;end
endmodule
