`timescale 1ns/1ps
module tb_regfile;
 reg clk=0,wen=0;always #5 clk=~clk;reg [4:0] wa,r1,r2;reg [31:0] wd;wire [31:0] d1,d2;integer n=0;
 regfile dut(.clk(clk),.wen(wen),.waddr(wa),.wdata(wd),.rs1(r1),.rs2(r2),.rd1(d1),.rd2(d2));
 initial begin wa=0;wd=0;r1=0;r2=0;#1;if(d1!==0||d2!==0)$fatal(1,"x0 read");
 @(negedge clk);wen=1;wa=5;wd=32'h12345678;r1=5;r2=5;#1;if(d1!==wd||d2!==wd)$fatal(1,"write-through");n=n+1;
 @(posedge clk);#1;wen=0;#1;if(d1!==32'h12345678||d2!==32'h12345678)$fatal(1,"stored read");n=n+1;
 @(negedge clk);wen=1;wa=0;wd=32'hffffffff;r1=0;#1;if(d1!==0)$fatal(1,"x0 write");n=n+1;
 $display("PASS tb_regfile %0d checks",n);$finish;end
endmodule
