`timescale 1ns/1ps

`include "program/defs.vh"

module tb_top;

    localparam integer IMEM_WORDS = 1024;
    localparam integer DMEM_WORDS = 512;
    localparam integer TRAP_LOG_WORD = 384;   // 0x600 / 4
    localparam [31:0]  NOP = 32'h0000_0013;

    reg         clk;
    reg         rst_n;

    wire [31:0] imem_addr;
    reg  [31:0] imem_rdata;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire        mem_ren;
    wire        mem_wen;
    wire [31:0] mem_rdata;

    wire        trap;
    wire [3:0]  trap_cause;
    wire [31:0] trap_pc;
    wire [31:0] trap_tval;

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];
    reg [31:0] expected [0:`TEST_NUM_RESULTS-1];
    reg [3:0]  trap_expected [0:`TEST_NUM_TRAPS-1];

    integer i;
    integer errors;
    integer trap_events;

    top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wmask  (mem_wmask),
        .mem_ren    (mem_ren),
        .mem_wen    (mem_wen),
        .mem_rdata  (mem_rdata),
        .trap       (trap),
        .trap_cause (trap_cause),
        .trap_pc    (trap_pc),
        .trap_tval  (trap_tval)
    );

    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Synchronous instruction memory (1-cycle read latency)
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (imem_addr[31:2] < IMEM_WORDS)
            imem_rdata <= imem[imem_addr[31:2]];
        else
            imem_rdata <= NOP;
    end

    // Combinational data-memory read; synchronous byte-masked write.
    assign mem_rdata = (mem_addr[31:2] < DMEM_WORDS) ? dmem[mem_addr[31:2]] : 32'b0;

    always @(posedge clk) begin
        if (mem_wen && (mem_addr[31:2] < DMEM_WORDS)) begin
            if (mem_wmask[0]) dmem[mem_addr[31:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wmask[1]) dmem[mem_addr[31:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wmask[2]) dmem[mem_addr[31:2]][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) dmem[mem_addr[31:2]][31:24] <= mem_wdata[31:24];
        end
    end

    // Trap activity log
    always @(posedge clk) begin
        if (rst_n && trap) begin
            trap_events = trap_events + 1;
            $display("[TRAP] pc=0x%08x cause=%0d tval=0x%08x",
                     trap_pc, trap_cause, trap_tval);
        end
    end


    task check_word;
        input integer index;
        input [31:0] actual;
        input [31:0] expected_value;
        begin
            if (actual !== expected_value) begin
                $display("[FAIL] result[%0d]: expected 0x%08x, got 0x%08x",
                         index, expected_value, actual);
                errors = errors + 1;
            end else begin
                $display("[PASS] result[%0d] = 0x%08x", index, actual);
            end
        end
    endtask

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        errors      = 0;
        trap_events = 0;

        for (i = 0; i < IMEM_WORDS; i = i + 1)
            imem[i] = NOP;
        for (i = 0; i < DMEM_WORDS; i = i + 1)
            dmem[i] = 32'b0;
        for (i = 0; i < `TEST_NUM_RESULTS; i = i + 1)
            expected[i] = 32'b0;
        for (i = 0; i < `TEST_NUM_TRAPS; i = i + 1)
            trap_expected[i] = 4'b0;

        $readmemh("program/program.hex"      , imem         );
        $readmemh("program/expected.hex"     , expected     );
        $readmemh("program/trap_expected.hex", trap_expected);

        // Hold reset across two rising clock edges.
        repeat (2) @(posedge clk);
        #1 rst_n = 1'b1;

        // 3000 cycles is ample for the directed program, traps and flushes.
        repeat (3000) @(posedge clk);
        #1;

        // ------------------------------------------------------------------
        // Result words
        // ------------------------------------------------------------------
        for (i = 0; i < `TEST_NUM_RESULTS; i = i + 1)
            check_word(i, dmem[i], expected[i]);

        // ------------------------------------------------------------------
        // Trap causes
        // ------------------------------------------------------------------
        for (i = 0; i < `TEST_NUM_TRAPS; i = i + 1) begin
            if (dmem[TRAP_LOG_WORD + 3*i] !== {28'd0, trap_expected[i]}) begin
                $display("[FAIL] trap[%0d] cause: expected %0d, got 0x%08x",
                         i, trap_expected[i], dmem[TRAP_LOG_WORD + 3*i]);
                errors = errors + 1;
            end else begin
                $display("[PASS] trap[%0d] cause = %0d", i, trap_expected[i]);
            end
        end

        // ------------------------------------------------------------------
        // Trap mepc / mtval sanity
        // ------------------------------------------------------------------
        for (i = 0; i < `TEST_NUM_TRAPS; i = i + 1) begin
            // mepc must be a valid 4-byte-aligned instruction address
            if ((dmem[TRAP_LOG_WORD + 3*i + 1] === 32'd0) ||
                (dmem[TRAP_LOG_WORD + 3*i + 1][1:0] !== 2'b00)) begin
                $display("[FAIL] trap[%0d] mepc invalid: 0x%08x",
                         i, dmem[TRAP_LOG_WORD + 3*i + 1]);
                errors = errors + 1;
            end
        end

        // ECALL / EBREAK / illegal: mtval = 0
        if (dmem[TRAP_LOG_WORD + 3*0 + 2] !== 32'd0 ||
            dmem[TRAP_LOG_WORD + 3*1 + 2] !== 32'd0 ||
            dmem[TRAP_LOG_WORD + 3*2 + 2] !== 32'd0) begin
            $display("[FAIL] trap mtval for ECALL/EBREAK/illegal is not zero");
            errors = errors + 1;
        end else begin
            $display("[PASS] trap mtval for ECALL/EBREAK/illegal = 0");
        end

        // Misaligned load/store: mtval = 0x402
        if (dmem[TRAP_LOG_WORD + 3*3 + 2] !== 32'h402 ||
            dmem[TRAP_LOG_WORD + 3*4 + 2] !== 32'h402) begin
            $display("[FAIL] trap mtval for misaligned access: 0x%08x / 0x%08x",
                     dmem[TRAP_LOG_WORD + 3*3 + 2], dmem[TRAP_LOG_WORD + 3*4 + 2]);
            errors = errors + 1;
        end else begin
            $display("[PASS] trap mtval for misaligned access = 0x402");
        end

        // Instruction-misaligned / CSR traps: mtval must carry a non-zero payload
        if ((dmem[TRAP_LOG_WORD + 3*5 + 2] === 32'd0) ||
            (dmem[TRAP_LOG_WORD + 3*6 + 2] === 32'd0) ||
            (dmem[TRAP_LOG_WORD + 3*7 + 2] === 32'd0)) begin
            $display("[FAIL] trap mtval for instruction-misaligned/CSR is zero");
            errors = errors + 1;
        end else begin
            $display("[PASS] trap mtval for instruction-misaligned/CSR is non-zero");
        end

        if (dut.u_rv32_core.u_id_stage.u_regfile.rf[31] !== `TEST_NUM_TRAPS) begin
            $display("[FAIL] trap count: expected %0d, got 0x%08x",
                     `TEST_NUM_TRAPS, dut.u_rv32_core.u_id_stage.u_regfile.rf[31]);
            errors = errors + 1;
        end else begin
            $display("[PASS] trap count = %0d", `TEST_NUM_TRAPS);
        end

        if (trap_events !== `TEST_NUM_TRAPS) begin
            $display("[FAIL] trap events: expected %0d, got %0d",
                     `TEST_NUM_TRAPS, trap_events);
            errors = errors + 1;
        end else begin
            $display("[PASS] trap events = %0d", `TEST_NUM_TRAPS);
        end

        if (errors == 0)
            $display("\n[PASS] tb_top completed with no errors.\n");
        else begin
            $display("\n[FAIL] tb_top completed with %0d error(s).\n", errors);
            $fatal(1, "tb_top result/trap mismatch");
        end

        $finish;
    end

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
