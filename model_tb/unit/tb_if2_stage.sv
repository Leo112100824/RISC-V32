`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"

module tb_if2_stage;
    reg clk = 0, rst_n = 0, flush = 0, stall = 0;
    reg [31:0] data = 0, pcq = 0;
    reg valid = 0;
    wire [31:0] instr, pc;
    wire ov;
    integer checks = 0;
    always #5 clk = ~clk;
    if2_stage dut(.clk(clk), .rst_n(rst_n), .flush(flush), .stall(stall),
        .imem_rdata(data), .if1_pc_q(pcq), .if1_data_valid(valid),
        .if2_instr(instr), .if2_pc(pc), .if2_valid(ov));

    task step(input bit s, f, v, input [31:0] p, d,
              input bit expected_valid, input [31:0] expected_pc, expected_instr,
              input string label_text);
        begin
            stall=s; flush=f; valid=v; pcq=p; data=d;
            @(posedge clk); #1;
            if (ov !== expected_valid ||
                (expected_valid && (pc !== expected_pc || instr !== expected_instr)))
                $fatal(1, "%s: valid=%b pc=%h instr=%h expected %b/%h/%h",
                    label_text, ov, pc, instr, expected_valid, expected_pc, expected_instr);
            checks++;
            @(negedge clk);
        end
    endtask

    initial begin
        @(negedge clk); rst_n=1;
        step(1,0,1,0,32'h00100093,0,0,0,"stall empty with PC zero");
        step(0,0,0,0,0,1,0,32'h00100093,"release buffered PC zero");
        step(0,1,0,0,0,0,0,0,"flush queue");
        step(0,0,1,4,32'h00200113,1,4,32'h00200113,"capture head");
        step(1,0,1,4,32'h00200113,1,4,32'h00200113,"stall duplicate head");
        step(0,0,0,0,0,0,0,0,"do not replay head");
        step(0,0,1,8,32'h00300193,1,8,32'h00300193,"next head");
        step(1,0,1,12,32'h00400213,1,8,32'h00300193,"buffer in-flight response");
        step(1,0,1,12,32'h00400213,1,8,32'h00300193,"repeated tail while stalled");
        step(0,0,1,12,32'h00400213,1,12,32'h00400213,"promote tail once");
        step(0,0,1,12,32'h00400213,0,0,0,"duplicate response consumed once");
        step(0,0,1,16,32'h00500293,1,16,32'h00500293,"capture after duplicate");
        step(1,0,1,20,32'h00600313,1,16,32'h00500293,"fill tail before flush");
        step(1,1,1,24,32'h00700393,0,0,0,"flush wins over stall and incoming");
        step(0,0,0,24,32'h00700393,0,0,0,"invalid old-path response ignored");
        step(0,0,1,32'h100,32'h00800413,1,32'h100,32'h00800413,"redirect target");
        $display("PASS tb_if2_stage %0d checks",checks);
        $finish;
    end
    initial begin #2000; $fatal(1,"tb_if2_stage watchdog"); end
endmodule
