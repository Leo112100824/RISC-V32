`timescale 1ns/1ps
module tb_forward_unit;
 reg [4:0] a,b,er,mr; reg ev,ew,el,ec,mv,mw; wire [1:0] fa,fb; integer n=0;
 forward_unit dut(.rs1_addr(a),.rs2_addr(b),.ex_mem_valid(ev),.ex_mem_wb_en(ew),.ex_mem_is_load(el),.ex_mem_is_csr(ec),.ex_mem_rd_addr(er),.mem_wb_valid(mv),.mem_wb_wb_en(mw),.mem_wb_rd_addr(mr),.fwd_a(fa),.fwd_b(fb));
 task ck(input [1:0] x,input [1:0] y);begin #1;if(fa!==x||fb!==y)$fatal(1,"forward got %0d,%0d expected %0d,%0d",fa,fb,x,y);n=n+1;end endtask
 initial begin a=5;b=6;er=5;mr=5;ev=1;ew=1;el=0;ec=0;mv=1;mw=1;ck(1,0);b=5;ck(1,1);el=1;ck(2,2);el=0;ec=1;ck(2,2);ec=0;ev=0;ck(2,2);mr=0;ck(0,0);$display("PASS tb_forward_unit %0d checks",n);$finish;end
endmodule
