`timescale 1ns/1ps
module tb_if_stage;
    reg clk=0, rst_n=0, redirect=0, stall=0;
    reg [31:0] redirect_pc=0;
    wire [31:0] addr, instr, pc;
    wire valid;
    reg [31:0] imem [0:127];
    reg [31:0] data=0;
    integer i, checks=0;

    always #5 clk=~clk;
    always @(posedge clk) data <= (addr[31:2] < 128) ? imem[addr[31:2]] : 32'h00000013;

    if_stage dut(.clk(clk),.rst_n(rst_n),.redirect(redirect),
        .redirect_pc(redirect_pc),.stall(stall),.imem_addr(addr),
        .imem_rdata(data),.if_instr(instr),.if_pc(pc),.if_valid(valid));

    task tick;
        begin @(posedge clk); #1; @(negedge clk); end
    endtask

    task expect_if(input bit v, input [31:0] p, d, input string label_text);
        begin
            if (valid !== v || (v && (pc !== p || instr !== d)))
                $fatal(1,"%s: got %b/%h/%h expected %b/%h/%h",label_text,valid,pc,instr,v,p,d);
            checks++;
        end
    endtask

    initial begin
        for(i=0;i<128;i++) imem[i]=32'h00000013+i;
        repeat(2) tick();
        rst_n=1;
        tick(); expect_if(1,0,32'h00000013,"first synchronous response");
        tick(); expect_if(1,4,32'h00000014,"sequential response");
        stall=1; tick(); expect_if(1,4,32'h00000014,"hold stalled instruction");
        tick(); expect_if(1,4,32'h00000014,"hold while response changes");
        stall=0; tick(); expect_if(1,8,32'h00000015,"resume without losing fetch");
        redirect=1; redirect_pc=32'h100; tick(); redirect=0;
        expect_if(0,0,0,"redirect flushes stale response");
        if(addr!==32'h100) $fatal(1,"redirect target address");
        checks++;
        tick(); expect_if(1,32'h100,32'h00000053,"redirect target response");
        $display("PASS tb_if_stage %0d checks",checks);
        $finish;
    end
    initial begin #2000; $fatal(1,"tb_if_stage watchdog"); end
endmodule
