`include "../../riscv_def.vh"

// IF stage for a one-cycle synchronous instruction memory.
// The delayed PC and memory output form the IF/ID boundary. A held entry keeps
// the current instruction stable during an ID hazard while the memory returns
// the next sequential instruction.





module if_stage (
    input  wire        clk,
    input  wire        rst_n,
    
    // 重定向
    input  wire        redirect,
    input  wire [31:0] redirect_pc,

    input  wire        stall,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    
    output wire [31:0] if_instr,
    output wire [31:0] if_pc,
    output wire        if_valid
);
    reg [31:0] pc;
    reg [31:0] pc_q;
    reg        response_valid;
    reg        held_valid;
    reg [31:0] held_instr;
    reg [31:0] held_pc;

    assign imem_addr = pc;
    assign if_instr  = held_valid ? held_instr :
                       response_valid ? imem_rdata : `NOP;
    assign if_pc     = held_valid ? held_pc : pc_q;
    assign if_valid  = held_valid | response_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc             <= 32'd0;
            pc_q           <= 32'd0;
            response_valid <= 1'b0;
            held_valid     <= 1'b0;
            held_instr     <= `NOP;
            held_pc        <= 32'd0;
        end else if (redirect) begin
            pc             <= redirect_pc;
            pc_q           <= 32'd0;
            response_valid <= 1'b0;
            held_valid     <= 1'b0;
            held_instr     <= `NOP;
            held_pc        <= 32'd0;
        end else begin
            if (!stall)
                pc <= pc + 32'd4;

            pc_q <= pc;
            if (stall) begin
                if (!held_valid && response_valid) begin
                    held_instr <= imem_rdata;
                    held_pc    <= pc_q;
                    held_valid <= 1'b1;
                end
            end else begin
                held_valid <= 1'b0;
            end

            // The memory samples the old address at this edge. Suppress the
            // response on the edge that applies a redirect; the target request
            // becomes valid at the following edge.
            response_valid <= !stall;
        end
    end
endmodule
