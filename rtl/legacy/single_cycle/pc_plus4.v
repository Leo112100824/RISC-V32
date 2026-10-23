module pc_plus4 (
    input  [31:0] pc      ,
    output [31:0] next_pc
);
    assign next_pc = pc + 32'd4 ;
    
endmodule
