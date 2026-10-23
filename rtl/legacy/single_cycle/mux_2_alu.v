
`include "../../riscv_def.vh"

// 本模块用于实现，多个数据源输入alu模块的选择

module mux_2_alu (
    
    input      [1:0]          alusrc    ,
    input      [`XLEN-1:0]    source1   ,
    input      [`XLEN-1:0]    source2   ,
    input      [`XLEN-1:0]    source3   ,
    input      [`XLEN-1:0]    source4   ,

    output     [`XLEN-1:0]    out_operand   

);
    
assign out_operand = (alusrc == 2'd0) ? source1 :
                     (alusrc == 2'd1) ? source2 :
                     (alusrc == 2'd2) ? source3 : source4;
                    
                             
                             

endmodule
