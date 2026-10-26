`include "../../riscv_def.vh"

// ============================================================================
//  if1_stage
//
//  流水线第 1 级：PC 寄存器 + 下一 PC 选择 + 取指地址产生。
//  目标存储器是同步读 BRAM：
//    本拍给出 imem_addr，下一拍 imem_rdata 才有效。
//  因此 IF1 只需要发地址，指令在 IF2 捕获。
//
//  imem_valid 是一个 2 位移位寄存器，用来标记“当前 imem_rdata 是否对应
//  一个真实发出的取指地址”，避免复位后把 X 当成指令。
// ============================================================================
module if1_stage (
    input  wire        clk,
    input  wire        rst_n,

    // 来自 EX：分支/跳转重定向（新的指令地址）
    input  wire        redirect,         
    input  wire [31:0] redirect_pc,

    // 来自 hazard_unit：load-use 停顿
    input  wire        stall,

    // 指令存储器接口
    output wire [31:0] imem_addr,

    // 送给 IF2 的地址/有效标志（与 imem_rdata 对齐）
    output wire [31:0] if1_pc_q,
    output wire        if1_data_valid
);

    reg  [31:0] pc;
    reg  [31:0] pc_q;
    reg  [1:0]  imem_valid;

    wire [31:0] pc_plus4;
    wire [31:0] next_pc;

    assign pc_plus4 = pc + 32'd4;

    // 如果没有重定向，则判断是否停顿，否则顺序 +4
    assign next_pc = redirect ? redirect_pc :
                     stall    ? pc          :
                                pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc         <= 32'd0;
            pc_q       <= 32'd0;
            imem_valid <= 2'b00;
        end else begin
            pc   <= next_pc;
            pc_q <= pc;

            if (redirect)
                imem_valid <= 2'b00;
            else if (stall)
                imem_valid <= imem_valid;
            else
                imem_valid <= {imem_valid[0], 1'b1};
        end
    end

    assign imem_addr      = pc;
    assign if1_pc_q       = pc_q;
    assign if1_data_valid = imem_valid[0];

endmodule
