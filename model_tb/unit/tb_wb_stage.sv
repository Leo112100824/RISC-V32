`timescale 1ns/1ps
module tb_wb_stage;
 reg v,en;reg [4:0] rd;reg [31:0] data;wire wen;wire [4:0] wa;wire [31:0] wd;integer n=0;
 wb_stage dut(.mem_wb_valid(v),.mem_wb_wb_en(en),.mem_wb_rd_addr(rd),.mem_wb_wb_data(data),.wb_wen(wen),.wb_waddr(wa),.wb_wdata(wd));
 task ck(input bit e);begin #1;if(wen!==e)$fatal(1,"wb enable mismatch");n=n+1;end endtask
 initial begin data=32'hdeadbeef;v=1;en=1;rd=1;ck(1);if(wa!=1||wd!=data)$fatal(1,"wb data");rd=0;ck(0);rd=2;en=0;ck(0);en=1;v=0;ck(0);$display("PASS tb_wb_stage %0d checks",n);$finish;end
endmodule
