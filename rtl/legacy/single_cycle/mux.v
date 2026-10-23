module mux #(parameter ADDR_WIDTH = 32) (
    input    [1:0]            pc_src  ,

    input    [ADDR_WIDTH-1:0]  source1 ,
    input    [ADDR_WIDTH-1:0]  source2 ,
    input    [ADDR_WIDTH-1:0]  source3 ,
    input    [ADDR_WIDTH-1:0]  source4 ,
 
    output   [ADDR_WIDTH-1:0]  pc
);

assign pc = (pc_src == 2'd0 ) ? source1 : 
            (pc_src == 2'd1 ) ? source2 :
            (pc_src == 2'd2 ) ? source3 : source4 ;

endmodule
