`include "../../riscv_def.vh"


module regfile (
    input  wire                         clk                        ,//时钟
    input  wire                         wen                        ,//写使能
    input  wire        [   4:0]         waddr                      ,//写地址（rd）32个
    input  wire        [  31:0]         wdata                      ,//写数据
    input  wire        [   4:0]         rs1                        ,//读地址1
    input  wire        [   4:0]         rs2                        ,//读地址2
    output wire        [  31:0]         rd1                        ,//读出数据1 
    output wire        [  31:0]         rd2                         //读出数据2
);
    (* ram_style = "distributed" *) reg [31:0] rf [0:31];

    //* 首先地址 != 0：x0 恒为 0，写入必须丢弃
    //* 写优先旁路：支持同拍读写同一寄存器（解决结构冒险）
//!写入
   always @(posedge clk) begin
       if (wen && waddr != 5'd0) rf[waddr] <= wdata;
   end
//!读出
   assign rd1 =  (rs1 == 5'd0) ? 32'd0 : (wen && (rs1 == waddr)) ? wdata : rf[rs1];
   assign rd2 =  (rs2 == 5'd0) ? 32'd0 : (wen && (rs2 == waddr)) ? wdata : rf[rs2]; 

endmodule