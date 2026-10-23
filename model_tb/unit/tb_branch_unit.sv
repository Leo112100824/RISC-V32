`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_branch_unit;
 reg [31:0] pc,a,b,imm; reg en; reg [3:0] typ; wire taken; wire [31:0] target; integer n=0;
 branch_unit dut(.pc(pc),.rs1_data(a),.rs2_data(b),.imm(imm),.branch_en(en),.branch_type(typ),.branch_taken(taken),.branch_target(target));
 task ck(input [3:0] t,input [31:0] x,input [31:0] y,input bit e);
 begin typ=t;a=x;b=y;#1;if(taken!==e)$fatal(1,"branch type %0d got %b expected %b",t,taken,e);n=n+1;end endtask
 initial begin pc=32'h100;imm=32'hfffffffc;en=1;#1;if(target!==32'hfc)$fatal(1,"target");
 ck(`BR_BEQ,3,3,1);ck(`BR_BNE,3,3,0);ck(`BR_BLT,32'hffffffff,0,1);ck(`BR_BGE,0,32'hffffffff,1);ck(`BR_BLTU,32'hffffffff,0,0);ck(`BR_BGEU,32'hffffffff,0,1);en=0;#1;if(taken)$fatal(1,"disabled branch");$display("PASS tb_branch_unit %0d checks",n);$finish;end
endmodule
