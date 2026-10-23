`timescale 1ns/1ps
`include "../../rtl/riscv_def.vh"
module tb_csr_file;
 reg clk=0,rst_n=0;always #5 clk=~clk;reg [11:0] addr=0,waddr=0;wire [31:0] rdata,mepc,ms,mtvec;wire implemented;reg we=0,trap=0,mret=0,retire=0;reg [31:0] wdata=0,tpc=0,tval=0;reg [3:0] cause=0;integer n=0;
 csr_file dut(.clk(clk),.rst_n(rst_n),.csr_addr(addr),.csr_rdata(rdata),.csr_implemented(implemented),.csr_we(we),.csr_waddr(waddr),.csr_wdata(wdata),.trap(trap),.trap_pc(tpc),.trap_cause(cause),.trap_tval(tval),.mret(mret),.retire(retire),.mepc_o(mepc),.mstatus_o(ms),.mtvec_o(mtvec));
 task writecsr(input [11:0] a,input [31:0] d);begin @(negedge clk);we=1;waddr=a;wdata=d;@(negedge clk);we=0;end endtask
 initial begin @(negedge clk);rst_n=1;
   writecsr(`CSR_MTVEC,32'h101);addr=`CSR_MTVEC;#1;if(rdata!=32'h101||mtvec!=32'h101)$fatal(1,"mtvec write/read");n=n+1;
   writecsr(`CSR_MEPC,32'h123);if(mepc!=32'h120)$fatal(1,"mepc alignment");n=n+1;
   addr=12'h777;#1;if(implemented)$fatal(1,"unimplemented flag");n=n+1;
   // Verify both halves of the 64-bit counters are independently writable.
   writecsr(`CSR_MCYCLEH,32'h12345678);writecsr(`CSR_MCYCLE,32'habcdef00);
   addr=`CSR_MCYCLEH;#1;if(rdata!=32'h12345678)$fatal(1,"mcycleh readback");
   addr=`CSR_MCYCLE;#1;if(rdata!=32'habcdef00)$fatal(1,"mcycle readback");n=n+1;
   writecsr(`CSR_MINSTRETH,32'hfedcba98);writecsr(`CSR_MINSTRET,32'h76543210);
   addr=`CSR_MINSTRETH;#1;if(rdata!=32'hfedcba98)$fatal(1,"minstreth readback");
   addr=`CSR_MINSTRET;#1;if(rdata!=32'h76543210)$fatal(1,"minstret readback");n=n+1;
   // Trap transfers MIE to MPIE and clears MIE; MRET restores it.
   writecsr(`CSR_MSTATUS,32'h00000008);if(ms[3]!==1'b1)$fatal(1,"mstatus MIE write");
   @(negedge clk);trap=1;tpc=32'h123;cause=11;tval=5;@(negedge clk);trap=0;
   if(mepc!=32'h120||ms[3]!==1'b0||ms[7]!==1'b1)$fatal(1,"trap mstatus");
   @(negedge clk);mret=1;@(negedge clk);mret=0;if(ms[3]!==1'b1||ms[7]!==1'b1)$fatal(1,"mret mstatus");n=n+1;
   addr=`CSR_MCAUSE;#1;if(rdata!==11)$fatal(1,"trap cause");n=n+1;
   addr=`CSR_MTVAL;#1;if(rdata!==5)$fatal(1,"trap mtval");n=n+1;
   // Counter rollover is reached through CSR writes, without forcing RTL state.
   writecsr(`CSR_MCYCLEH,32'h12345678);writecsr(`CSR_MCYCLE,32'hffffffff);
   @(posedge clk);#1;addr=`CSR_MCYCLEH;#1;if(rdata!==32'h12345679)$fatal(1,"mcycle carry into high half");
   addr=`CSR_MCYCLE;#1;if(rdata!==0)$fatal(1,"mcycle rollover low half");n=n+1;
   writecsr(`CSR_MINSTRETH,32'h12345678);writecsr(`CSR_MINSTRET,32'hffffffff);retire=1;
   @(posedge clk);#1;addr=`CSR_MINSTRETH;#1;if(rdata!==32'h12345679)$fatal(1,"minstret carry into high half");
   addr=`CSR_MINSTRET;#1;if(rdata!==0)$fatal(1,"minstret rollover low half");n=n+1;
   @(negedge clk);retire=0;@(posedge clk);#1;if(rdata!==0)$fatal(1,"minstret bubble must not increment");n=n+1;
   // A committed older mstatus write must feed younger trap/MRET bit updates.
   @(negedge clk);we=1;waddr=`CSR_MSTATUS;wdata=32'h8;trap=1;tpc=32'h456;cause=2;tval=32'hdeadbeef;
   @(negedge clk);we=0;trap=0;if(ms[3]!==0||ms[7]!==1||mepc!==32'h454)$fatal(1,"CSR mstatus write plus trap ordering");n=n+1;
   @(negedge clk);we=1;waddr=`CSR_MEPC;wdata=32'h800;trap=1;tpc=32'h900;
   @(negedge clk);we=0;trap=0;if(mepc!==32'h900)$fatal(1,"trap mepc overrides CSR write");n=n+1;
   @(negedge clk);we=1;waddr=`CSR_MSTATUS;wdata=32'h80;mret=1;
   @(negedge clk);we=0;mret=0;if(ms[3]!==1||ms[7]!==1)$fatal(1,"CSR mstatus write plus MRET ordering");n=n+1;
   $display("PASS tb_csr_file %0d checks",n);$finish;end
endmodule
