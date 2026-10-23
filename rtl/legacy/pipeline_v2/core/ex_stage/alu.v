`include "../../riscv_def.vh"

module alu (
    
    input  wire        [  31:0]         operand_a                  ,//操作数
    input  wire        [  31:0]         operand_b                  ,//操作数
    input  wire        [   3:0]         alu_op                     ,//操作类型

    output reg         [  31:0]         alu_result                  //操作结果

);



always @(*) begin
    case (alu_op)
     `ALU_ADD   : alu_result = operand_a + operand_b ;
     `ALU_SUB   : alu_result = operand_a - operand_b ;
     `ALU_SLL   : alu_result = operand_a << operand_b[4:0]  ;
     `ALU_SLT   : alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0 ;
     `ALU_SLTU  : alu_result = (operand_a < operand_b) ? 32'd1 : 32'd0;
     `ALU_XOR   : alu_result = operand_a ^ operand_b ;
     `ALU_SRL   : alu_result = operand_a >> operand_b[4:0] ;
     `ALU_SRA   : alu_result = $signed(operand_a) >>> operand_b[4:0];
     `ALU_OR    : alu_result = operand_a | operand_b ;
     `ALU_AND   : alu_result = operand_a & operand_b ;
  
    default: alu_result= 32'd0;
    endcase
end

    
endmodule