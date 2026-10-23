`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_alu;
  reg [31:0] a,b; reg [3:0] op; wire [31:0] y; integer n=0;
  alu dut(.operand_a(a),.operand_b(b),.alu_op(op),.alu_result(y));
  task check(input [3:0] o,input [31:0] x,input [31:0] z,input [31:0] e);
    begin a=x;b=z;op=o;#1;if(y!==e) begin $display("FAIL alu op=%0d got=%h expected=%h",o,y,e);$fatal(1);end n=n+1;end
  endtask
  initial begin
    check(`ALU_ADD,32'hffffffff,1,0); check(`ALU_SUB,7,9,32'hfffffffe);
    check(`ALU_SLL,1,31,32'h80000000); check(`ALU_SLT,32'hffffffff,0,1);
    check(`ALU_SLTU,32'hffffffff,0,0); check(`ALU_XOR,32'ha5,32'h3c,32'h99);
    check(`ALU_SRL,32'h80000000,31,1); check(`ALU_SRA,32'h80000000,31,32'hffffffff);
    check(`ALU_OR,32'ha0,32'h0f,32'haf); check(`ALU_AND,32'ha5,32'h3c,32'h24);
    $display("PASS tb_alu %0d checks",n);$finish;
  end
endmodule
