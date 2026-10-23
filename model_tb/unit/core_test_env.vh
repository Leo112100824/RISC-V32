// Shared memory/scoreboard for the independent rv32_core and top benches.
// Each enclosing bench directly instantiates its DUT and names BENCH_NAME.
reg clk=0, rst_n=0;
always #5 clk=~clk;
reg [31:0] imem_rdata=32'h00000013;
wire [31:0] imem_addr,mem_addr,mem_wdata,tpc,ttv;
wire [3:0] mem_wmask,tcause;
wire mem_ren,mem_wen,trap;
wire trap_overlap;
reg saw_trap_overlap=0;
wire [31:0] mem_rdata;
reg [31:0] imem[0:127],dmem[0:127];
integer trap_count=0,scenario=0,checks=0,i;
reg [31:0] expected_trap_pc,expected_trap_tval;
reg [3:0] expected_cause;

function automatic [31:0] addi(input [4:0] rd,rs1,input integer imm);
    addi={imm[11:0],rs1,3'b000,rd,7'h13};
endfunction
function automatic [31:0] lw(input [4:0] rd,rs1,input integer imm);
    lw={imm[11:0],rs1,3'b010,rd,7'h03};
endfunction
function automatic [31:0] sw(input [4:0] rs2,rs1,input integer imm);
    sw={imm[11:5],rs2,rs1,3'b010,imm[4:0],7'h23};
endfunction
function automatic [31:0] csrrw(input [4:0] rd,input [11:0] csr,input [4:0] rs1);
    csrrw={csr,rs1,3'b001,rd,7'h73};
endfunction
function automatic [31:0] csrr(input [4:0] rd,input [11:0] csr);
    csrr={csr,5'd0,3'b010,rd,7'h73};
endfunction

always @(posedge clk) begin
    if(imem_addr[31:2]<128) imem_rdata<=imem[imem_addr[31:2]];
    else imem_rdata<=32'h00000013;
    if(rst_n && mem_wen) begin
        if(mem_addr[31:2]>=128 || mem_addr[1:0]!==0 || mem_wmask!==4'hf)
            $fatal(1,"%s unexpected memory write %h mask=%b",BENCH_NAME,mem_addr,mem_wmask);
        for(integer lane=0;lane<4;lane++)
            if(mem_wmask[lane]) dmem[mem_addr[31:2]][8*lane+:8]<=mem_wdata[8*lane+:8];
    end
    if(rst_n && trap) begin
        if(trap_count!=0 || tcause!==expected_cause ||
           tpc!==expected_trap_pc || ttv!==expected_trap_tval)
            $fatal(1,"%s scenario %0d trap #%0d cause=%d pc=%h tval=%h",
                BENCH_NAME,scenario,trap_count,tcause,tpc,ttv);
        trap_count++;
    end
    if(rst_n && trap_overlap) saw_trap_overlap=1;
end
assign mem_rdata=(mem_addr[31:2]<128)?dmem[mem_addr[31:2]]:32'b0;

task ck(input logic ok,input string label_text);
    begin
        if(ok!==1'b1)$fatal(1,"%s scenario %0d: %s",BENCH_NAME,scenario,label_text);
        checks++;
    end
endtask

task clear_program;
    begin
        rst_n=0;
        repeat(2) @(negedge clk);
        for(i=0;i<128;i++)begin imem[i]=32'h00000013;dmem[i]=0;end
        trap_count=0;
        saw_trap_overlap=0;
        // Set direct trap vector. All test programs explicitly initialize the
        // registers they read; the register file intentionally has no reset.
        imem[0]=addi(1,0,128);
        imem[1]=csrrw(0,12'h305,1);
    end
endtask

task handler(input integer resume_bytes);
    begin
        imem[32]=csrr(10,12'h342);
        imem[33]=sw(10,0,16);
        imem[34]=csrr(11,12'h341);
        imem[35]=sw(11,0,20);
        imem[36]=csrr(12,12'h343);
        imem[37]=sw(12,0,24);
        imem[38]=addi(11,11,resume_bytes);
        imem[39]=csrrw(0,12'h341,11);
        imem[40]=32'h30200073; // MRET immediately consumes the new mepc.
    end
endtask

task complete_at(input integer word_index);
    begin
        imem[word_index]=addi(30,0,1);
        imem[word_index+1]=sw(30,0,256); // End-of-test signature.
        imem[word_index+2]=32'h0000006f;
    end
endtask

task execute;
    integer cycles;
    begin
        rst_n=1;
        cycles=0;
        while(dmem[64]!==32'd1 && cycles<300)begin
            @(negedge clk);cycles++;
        end
        ck(dmem[64]===1,"completion signature within 300 cycles");
        ck(trap_count===1,"exactly one trap delivered");
        ck(dmem[4]==={28'd0,expected_cause},"handler reads exact mcause");
        ck(dmem[5]===expected_trap_pc,"handler reads exact mepc");
        ck(dmem[6]===expected_trap_tval,"handler reads exact mtval");
        $display("[PROGRAM] %s scenario=%0d cycles_to_signature=%0d",BENCH_NAME,scenario,cycles);
    end
endtask

initial begin
    scenario=1;clear_program();handler(4);
    imem[2]=addi(2,0,7);
    imem[3]=addi(3,2,5);            // EX/MEM RAW.
    imem[4]=sw(3,0,0);
    imem[5]=lw(4,0,0);
    imem[6]=32'h003202b3;          // ADD x5,x4,x3: load-use RAW.
    imem[7]=sw(5,0,4);
    imem[8]=32'h00528663;          // BEQ x5,x5,+12.
    imem[9]=sw(0,0,0);             // Wrong-path store must be flushed.
    imem[10]=32'hffffffff;         // Wrong-path illegal must not trap.
    imem[11]=csrrw(0,12'h340,5);
    imem[12]=csrr(6,12'h340);
    imem[13]=addi(7,6,1);          // CSR-use RAW.
    imem[14]=sw(7,0,8);
    imem[15]=32'h00000073;         // ECALL at PC=60.
    imem[16]=sw(7,0,12);           // Executes after handler MRET.
    complete_at(17);
    expected_cause=11;expected_trap_pc=60;expected_trap_tval=0;
    execute();
    ck(dmem[0]===12,"forwarded sum and wrong-path store suppression");
    ck(dmem[1]===24,"load-use dependency result");
    ck(dmem[2]===25,"CSR-use dependency result");
    ck(dmem[3]===25,"MRET returns to instruction after ECALL");

    scenario=2;clear_program();handler(8);
    imem[2]=addi(2,0,55);
    imem[3]=sw(2,0,0);             // Older store must commit.
    imem[4]=lw(3,0,2);             // MEM misalignment at PC=16.
    imem[5]=32'h00000073;          // Simultaneous younger EX ECALL.
    imem[6]=sw(2,0,4);             // Handler resumes here, skipping both.
    complete_at(7);
    expected_cause=4;expected_trap_pc=16;expected_trap_tval=2;
    execute();
    ck(saw_trap_overlap,"observed simultaneous MEM and EX trap requests");
    ck(dmem[0]===55,"older store survives precise trap");
    ck(dmem[1]===55,"handler resumes at requested mepc");
    ck(dmem[2]===0 && dmem[3]===0,"no unexpected memory side effects");
    $display("PASS %s %0d checks",BENCH_NAME,checks);
    $finish;
end
initial begin #10000;$fatal(1,"%s program watchdog",BENCH_NAME);end
