`timescale 1ns/1ps
module tb_if1_stage;
 reg clk=0,rst_n=0,redirect=0,stall=0;reg [31:0] redirect_pc=0;wire [31:0] addr,pcq;wire valid;always #5 clk=~clk;integer n=0;
 if1_stage dut(.clk(clk),.rst_n(rst_n),.redirect(redirect),.redirect_pc(redirect_pc),.stall(stall),.imem_addr(addr),.if1_pc_q(pcq),.if1_data_valid(valid));
 initial begin @(negedge clk);rst_n=1;@(negedge clk);if(addr!==4)$fatal(1,"pc+4");n=n+1;stall=1;@(negedge clk);if(addr!==4)$fatal(1,"stall pc");n=n+1;redirect=1;redirect_pc=32'h100;@(negedge clk);redirect=0;stall=0;if(addr!==32'h100||valid)$fatal(1,"redirect priority/valid clear");n=n+1;@(negedge clk);if(addr!==32'h104||!valid)$fatal(1,"redirect fetch");n=n+1;$display("PASS tb_if1_stage %0d checks",n);$finish;end
endmodule
