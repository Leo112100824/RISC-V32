`include "../../riscv_def.vh"

// ============================================================================
//  if2_stage
//
//  流水线第 2 级：同步指令存储器的输出捕获 + 两级取指队列。
//
//  为什么需要 skid buffer：
//    同步 BRAM 有一拍读延迟，IF1 的 PC 实际上比 IF2 中的指令超前两条。
//    如果 load-use 停顿只是冻结 IF1/IF2，那么停在 imem_rdata 上的那条
//    在途指令会被下一拍的 BRAM 输出覆盖，造成丢指令。
//
//  本模块用 head + tail 两个表项组成 1 深度的 skid buffer：
//    - 正常：head 每拍被 ID 消费，tail/incoming 依次补位
//    - 停顿：head 保持（ID 中的指令），incoming 存入 tail
//    - 释放：head 送 ID/EX，tail 升为 head，incoming 进入 tail
//
//  去重：
//    停顿期间 PC 保持，同步 BRAM 会重复输出同一条指令；如果直接入队，
//    head 和 tail 会拿到同一个 PC，导致该指令执行两次。入队前比较 PC
//    可以消除这种重复。
// ============================================================================
module if2_stage (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        flush,
    input  wire        stall,

    input  wire [31:0] imem_rdata,
    input  wire [31:0] if1_pc_q,
    input  wire        if1_data_valid,

    output reg  [31:0] if2_instr,
    output reg  [31:0] if2_pc,
    output reg         if2_valid
);

    // head 表项就是 IF2/ID 边界的指令；tail 是 1 深度 skid
    reg [31:0] tail_instr;
    reg [31:0] tail_pc;
    reg        tail_valid;

    wire incoming_new_vs_tail;

    assign incoming_new_vs_tail = if1_data_valid && (if1_pc_q != tail_pc);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if2_instr  <= `NOP;
            if2_pc     <= 32'd0;
            if2_valid  <= 1'b0;
            tail_instr <= `NOP;
            tail_pc    <= 32'd0;
            tail_valid <= 1'b0;
        end else if (flush) begin
            // 分支/跳转：丢弃整个取指队列
            if2_instr  <= `NOP;
            if2_pc     <= 32'd0;
            if2_valid  <= 1'b0;
            tail_instr <= `NOP;
            tail_pc    <= 32'd0;
            tail_valid <= 1'b0;
        end else if (stall) begin
            // head 保持给 ID；把当前在途指令收进 tail（只收一次）
            if (incoming_new_vs_tail && !tail_valid) begin
                tail_instr <= imem_rdata;
                tail_pc    <= if1_pc_q;
                tail_valid <= 1'b1;
            end
        end else begin
            if (tail_valid) begin
                // tail 升为 head；incoming 只在不是同一条指令时进入 tail
                if2_instr <= tail_instr;
                if2_pc    <= tail_pc;
                if2_valid <= 1'b1;

                if (incoming_new_vs_tail) begin
                    tail_instr <= imem_rdata;
                    tail_pc    <= if1_pc_q;
                    tail_valid <= 1'b1;
                end else begin
                    tail_valid <= 1'b0;
                end
            end else begin
                // 队列为空：接收在途指令；头无效时不做重复检查，但仍要求 valid
                if (if1_data_valid && (!if2_valid || (if1_pc_q != if2_pc))) begin
                    if2_instr <= imem_rdata;
                    if2_pc    <= if1_pc_q;
                    if2_valid <= 1'b1;
                end else begin
                    if2_instr <= `NOP;
                    if2_pc    <= 32'd0;
                    if2_valid <= 1'b0;
                end
                tail_valid <= 1'b0;
            end
        end
    end

endmodule
