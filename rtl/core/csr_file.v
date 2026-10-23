`include "../riscv_def.vh"

// ============================================================================
//  csr_file
//
//  Machine-mode CSR 文件（RV32I + Zicsr）：
//    mstatus / misa / mie / mtvec / mscratch / mepc / mcause / mtval / mip
//    mcycle / minstret / mcycleh / minstreth / mhartid
//
//  端口分三类：
//    1. CSR 指令读口：MEM 级组合读，返回旧值
//    2. CSR 指令写口：MEM 级写，写使能由 MEM 级做只读/未实现检查
//    3. 机器模式事件：trap / mret / retire
//
//  写优先级：
//    trap > mret > CSR 指令写 > 计数器自增
//  其中 mstatus 的 CSR 写会先于 trap/mret 的位更新生效，保证“older CSR
//  指令先提交，younger 指令再陷入”的顺序。
// ============================================================================
module csr_file (
    input  wire        clk,
    input  wire        rst_n,

    // CSR instruction read port (MEM stage)
    input  wire [11:0] csr_addr,
    output reg  [31:0] csr_rdata,
    output reg         csr_implemented,

    // CSR instruction write port (MEM stage)
    input  wire        csr_we,
    input  wire [11:0] csr_waddr,
    input  wire [31:0] csr_wdata,

    // Trap entry
    input  wire        trap,
    input  wire [31:0] trap_pc,
    input  wire [3:0]  trap_cause,
    input  wire [31:0] trap_tval,

    // MRET
    input  wire        mret,

    // Retirement (minstret)
    input  wire        retire,

    // Direct outputs for MRET / trap target
    output wire [31:0] mepc_o,
    output wire [31:0] mstatus_o,
    output wire [31:0] mtvec_o
);

    reg [31:0] mstatus;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    reg [31:0] mie;
    reg [31:0] mip;

    reg [63:0] mcycle;
    reg [63:0] minstret;

    wire [31:0] misa;

    assign misa = 32'h4000_0100;   // RV32I

    assign mepc_o    = mepc;
    assign mstatus_o = mstatus;
    assign mtvec_o   = mtvec;

    // ------------------------------------------------------------------
    // Read mux
    // ------------------------------------------------------------------
    always @(*) begin
        csr_rdata       = 32'd0;
        csr_implemented = 1'b1;

        case (csr_addr)
            `CSR_MSTATUS:  csr_rdata = mstatus;
            `CSR_MISA:     csr_rdata = misa;
            `CSR_MIE:      csr_rdata = mie;
            `CSR_MTVEC:    csr_rdata = mtvec;
            `CSR_MSCRATCH: csr_rdata = mscratch;
            `CSR_MEPC:     csr_rdata = mepc;
            `CSR_MCAUSE:   csr_rdata = mcause;
            `CSR_MTVAL:    csr_rdata = mtval;
            `CSR_MIP:      csr_rdata = mip;
            `CSR_MCYCLE:   csr_rdata = mcycle[31:0];
            `CSR_MINSTRET: csr_rdata = minstret[31:0];
            `CSR_MCYCLEH:  csr_rdata = mcycle[63:32];
            `CSR_MINSTRETH: csr_rdata = minstret[63:32];
            `CSR_MHARTID:  csr_rdata = 32'd0;
            default: begin
                csr_rdata       = 32'd0;
                csr_implemented = 1'b0;
            end
        endcase
    end

    // ------------------------------------------------------------------
    // State update
    // ------------------------------------------------------------------
    reg [31:0] ms_next;
    reg [63:0] mcycle_next;
    reg [63:0] minstret_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus  <= 32'd0;
            mtvec    <= 32'd0;
            mscratch <= 32'd0;
            mepc     <= 32'd0;
            mcause   <= 32'd0;
            mtval    <= 32'd0;
            mie      <= 32'd0;
            mip      <= 32'd0;
            mcycle   <= 64'd0;
            minstret <= 64'd0;
        end else begin
            // 默认：mcycle 每拍自增，minstret 在指令退休时自增
            ms_next       = mstatus;
            mcycle_next   = mcycle + 64'd1;
            minstret_next = minstret + (retire ? 64'd1 : 64'd0);

            // ------------------------------------------------------------------
            // CSR 指令写（older instruction，先于同拍 trap/mret 生效）
            // ------------------------------------------------------------------
            if (csr_we) begin
                case (csr_waddr)
                    `CSR_MSTATUS:  ms_next = csr_wdata;
                    `CSR_MIE:      mie      <= csr_wdata;
                    `CSR_MTVEC:    mtvec    <= csr_wdata;
                    `CSR_MSCRATCH: mscratch <= csr_wdata;
                    `CSR_MEPC:     mepc     <= {csr_wdata[31:2], 2'b00};
                    `CSR_MCAUSE:   mcause   <= csr_wdata;
                    `CSR_MTVAL:    mtval    <= csr_wdata;
                    `CSR_MIP:      mip      <= csr_wdata;
                    `CSR_MCYCLE:   mcycle_next[31:0]   = csr_wdata;
                    `CSR_MCYCLEH:  mcycle_next[63:32]  = csr_wdata;
                    `CSR_MINSTRET: minstret_next[31:0] = csr_wdata;
                    `CSR_MINSTRETH: minstret_next[63:32] = csr_wdata;
                    default: ;
                endcase
            end

            // ------------------------------------------------------------------
            // MRET：MIE <- MPIE，MPIE <- 1，MPP <- M
            // ------------------------------------------------------------------
            if (mret) begin
                ms_next[`MSTATUS_MIE_BIT]  = ms_next[`MSTATUS_MPIE_BIT];
                ms_next[`MSTATUS_MPIE_BIT] = 1'b1;
                ms_next[12:11]             = 2'b11;
            end

            // ------------------------------------------------------------------
            // Trap：优先级最高
            // ------------------------------------------------------------------
            if (trap) begin
                mepc   <= {trap_pc[31:2], 2'b00};
                mcause <= {28'd0, trap_cause};
                mtval  <= trap_tval;

                ms_next[`MSTATUS_MPIE_BIT] = ms_next[`MSTATUS_MIE_BIT];
                ms_next[`MSTATUS_MIE_BIT]  = 1'b0;
                ms_next[12:11]             = 2'b11;
            end

            mstatus  <= ms_next;
            mcycle   <= mcycle_next;
            minstret <= minstret_next;
        end
    end

endmodule
