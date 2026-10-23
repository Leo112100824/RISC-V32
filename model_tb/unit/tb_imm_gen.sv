`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_imm_gen;
 reg [31:0] ins;reg [2:0] typ;wire [31:0] imm;integer n=0;
 imm_gen dut(.instruction(ins),.instruction_type(typ),.immediate(imm));
 task ck(input [2:0] t,input [31:0] i,input [31:0] e);begin typ=t;ins=i;#1;if(imm!==e)$fatal(1,"imm type %0d got %h expected %h",t,imm,e);n=n+1;end endtask
 initial begin ck(`I_TYPE,32'hfff00000,32'hffffffff);ck(`S_TYPE,32'hfe000f80,32'hffffffff);ck(`B_TYPE,32'hfe000e80,32'hfffffffc);ck(`U_TYPE,32'h12345000,32'h12345000);ck(`J_TYPE,32'h80000000,32'hfff00000);ck(`CSR_TYPE,32'h00078000,15);$display("PASS tb_imm_gen %0d checks",n);$finish;end
endmodule
