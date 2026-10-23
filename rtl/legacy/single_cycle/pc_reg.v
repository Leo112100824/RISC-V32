module pc_reg (
    input               clk              ,
    input               rst_n            ,
    input       [31:0]  next_pc          ,
    output reg  [31:0]  pc   
);
    

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 32'd0 ;
    end else begin
        pc <=  next_pc ;
    end
end


endmodule