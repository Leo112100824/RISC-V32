`timescale 1ns/1ps
module tb_hazard_unit;
 reg xv,l,c,we,iv,ill,u1,u2;reg [4:0] rd,r1,r2;wire stall;integer n=0;
 hazard_unit dut(.id_ex_valid(xv),.id_ex_mem_read(l),.id_ex_csr(c),.id_ex_wb_en(we),.id_ex_rd_addr(rd),.id_valid(iv),.id_illegal(ill),.id_rs1_used(u1),.id_rs2_used(u2),.id_rs1_addr(r1),.id_rs2_addr(r2),.stall(stall));
 task ck(input bit e);begin #1;if(stall!==e)$fatal(1,"hazard got %b expected %b",stall,e);n=n+1;end endtask
 initial begin xv=1;l=1;c=0;we=1;rd=5;iv=1;ill=0;u1=1;u2=0;r1=5;r2=0;ck(1);u1=0;u2=1;r2=5;ck(1);ill=1;ck(0);ill=0;r2=4;ck(0);c=1;l=0;r1=5;u1=1;ck(1);rd=0;ck(0);xv=0;rd=5;ck(0);$display("PASS tb_hazard_unit %0d checks",n);$finish;end
endmodule
