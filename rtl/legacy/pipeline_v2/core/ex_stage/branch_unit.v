
`include "../../riscv_def.vh"



module branch_unit (
    input              [`XLEN-1:0]      pc                         ,
    input              [`XLEN-1:0]      rs1_data                   ,
    input              [`XLEN-1:0]      rs2_data                   ,
    input              [`XLEN-1:0]      imm                        ,

    input                               branch_en                  ,
    input              [   3:0]         branch_type                ,

    output reg                          branch_taken               ,
    output             [`XLEN-1:0]      branch_target               
);

    // 分支跳转目标
    assign branch_target = pc + imm;

    always @(*) begin
        branch_taken = 1'b0;

        if (branch_en) begin
            case (branch_type)
                `BR_BEQ:
                    branch_taken = (rs1_data == rs2_data);
                `BR_BNE:
                    branch_taken = (rs1_data != rs2_data);
                `BR_BLT:
                    branch_taken = ($signed(rs1_data) < $signed(rs2_data));
                `BR_BGE:
                    branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
                `BR_BLTU:
                    branch_taken = (rs1_data < rs2_data);
                `BR_BGEU:
                    branch_taken = (rs1_data >= rs2_data);
                default:
                    branch_taken = 1'b0;
            endcase
        end
    end

endmodule
