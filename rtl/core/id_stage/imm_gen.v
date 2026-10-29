
`include "../../riscv_def.vh"

module imm_gen (
    input  [31:0] instruction     ,
    input  [2:0]  instruction_type,
    output [31:0] immediate
);
    

assign immediate = (instruction_type == `I_TYPE)   ? {{20{instruction[31]}}, instruction[31:20]} :
                   (instruction_type == `S_TYPE)   ? {{20{instruction[31]}}, instruction[31:25], instruction[11:7]} :
                   (instruction_type == `B_TYPE)   ? {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0} :
                   (instruction_type == `U_TYPE)   ? {instruction[31:12], 12'b0} :
                   (instruction_type == `J_TYPE)   ? {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0} :
                   (instruction_type == `CSR_TYPE) ? {27'b0, instruction[19:15]} :
                   32'b0;



endmodule