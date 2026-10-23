`include "../riscv_def.vh"

// RV32I single-cycle core integration.
// Instruction and data memories are kept outside the core so this module can
// be reused with a testbench, FPGA BRAM, or an SoC bus adapter.
module top (
    input  wire                 clk,
    input  wire                 rst_n,

    output wire [`XLEN-1:0]     imem_addr,
    input  wire [`XLEN-1:0]     imem_rdata,

    output wire [`XLEN-1:0]     mem_addr,
    output wire [`XLEN-1:0]     mem_wdata,
    output wire [3:0]           mem_wmask,
    output wire                 mem_ren,
    output wire                 mem_wen,
    input  wire [`XLEN-1:0]     mem_rdata,

    output wire                 illegal_instr
);
// *PC选择
    wire [`XLEN-1:0] pc;
    wire [`XLEN-1:0] pc_plus_4;
    wire [`XLEN-1:0] next_pc;
    wire [`XLEN-1:0] jal_target;
    wire [`XLEN-1:0] jalr_target;
    wire [`XLEN-1:0] branch_target;
    wire [1:0]        pc_src_control;
    wire [1:0]        pc_src_effective;
// *ID预解码
    wire [5:0] instruction_id;
    wire [2:0] instruction_type;
    wire       rs1_used;
    wire       rs2_used;
// *control_unit
    wire [4:0] rs1_addr;
    wire [4:0] rs2_addr;
    wire [4:0] rd_addr;
    wire [`XLEN-1:0] rs1_data;
    wire [`XLEN-1:0] rs2_data;

    wire              wb_en;
    wire [2:0]        reg_wsrc;
    reg  [`XLEN-1:0]  wb_data;

    wire [1:0] alu_src_1_sel;
    wire [1:0] alu_src_2_sel;
    wire [3:0] alu_op;
    wire [`XLEN-1:0] alu_operand_1;
    wire [`XLEN-1:0] alu_operand_2;
    wire [`XLEN-1:0] alu_result;

    wire [2:0]        imm_type;
    wire [`XLEN-1:0] imm_instr;
    wire [`XLEN-1:0] immediate;

    wire       mem_rd_en;
    wire       mem_wr_en;
    wire [1:0] mem_size;
    wire       mem_unsigned;
    wire [`XLEN-1:0] load_data;

    wire       branch_en;
    wire [3:0] branch_type;
    wire       branch_taken;

    assign imem_addr = pc;
    assign rs1_addr  = imem_rdata[19:15];
    assign rs2_addr  = imem_rdata[24:20];

    // Branches have priority over the sequential path. JAL/JALR are selected
    // by the control unit; source4 is reserved for a taken conditional branch.
    assign pc_src_effective = branch_taken ? 2'd3 : pc_src_control;
    assign jal_target       = pc + immediate;
    assign jalr_target      = {alu_result[`XLEN-1:1], 1'b0};

    pc_reg u_pc_reg (
        .clk     (clk),
        .rst_n   (rst_n),
        .next_pc (next_pc),
        .pc      (pc)
    );

    pc_plus4 u_pc_plus4 (
        .pc      (pc),
        .next_pc (pc_plus_4)
    );

    mux #(.ADDR_WIDTH(`XLEN)) u_pc_mux (
        .pc_src  (pc_src_effective),
        .source1 (pc_plus_4),
        .source2 (jalr_target),
        .source3 (jal_target),
        .source4 (branch_target),
        .pc      (next_pc)
    );

    decode u_decode (
        .instr            (imem_rdata),
        .instruction_id   (instruction_id),
        .instruction_type (instruction_type),
        .rs1_used         (rs1_used),
        .rs2_used         (rs2_used),
        .illegal_instr    (illegal_instr)
    );

    control_unit u_control_unit (
    .instr_id                          (instruction_id            ),
    .instr_type                        (instruction_type          ),
    .instr                             (imem_rdata                ),
    .wb_en                             (wb_en                     ),
    .reg_wsrc                          (reg_wsrc                  ),
    .rd_addr                           (rd_addr                   ),
    .ALUsrc_1                          (alu_src_1_sel             ),
    .ALUsrc_2                          (alu_src_2_sel             ),
    .ALU_op                            (alu_op                    ),
    .control_unit_2_imm_type           (imm_type                  ),
    .control_unit_2_imm_instr          (imm_instr                 ),
    .mem_rd_en                         (mem_rd_en                 ),
    .mem_wr_en                         (mem_wr_en                 ),
    .mem_size                          (mem_size                  ),
    .mem_unsigned                      (mem_unsigned              ),
    .branch_en                         (branch_en                 ),
    .branch_type                       (branch_type               ),
    .pc_src                            (pc_src_control            ) 
    );

    imm_gen u_imm_gen (
        .instruction      (imm_instr),
        .instruction_type (imm_type),
        .immediate        (immediate)
    );

    regfile u_regfile (
        .clk   (clk),
        .wen   (wb_en && !illegal_instr),
        .waddr (rd_addr),
        .wdata (wb_data),
        .rs1   (rs1_addr),
        .rs2   (rs2_addr),
        .rd1   (rs1_data),
        .rd2   (rs2_data)
    );

    mux_2_alu u_alu_src_1_mux (
        .alusrc      (alu_src_1_sel),
        .source1     (rs1_data),
        .source2     (pc),
        .source3     ({`XLEN{1'b0}}),
        .source4     ({`XLEN{1'b0}}),
        .out_operand (alu_operand_1)
    );

    mux_2_alu u_alu_src_2_mux (
        .alusrc      (alu_src_2_sel),
        .source1     (rs2_data),
        .source2     (immediate),
        .source3     ({`XLEN{1'b0}}),
        .source4     ({`XLEN{1'b0}}),
        .out_operand (alu_operand_2)
    );

    alu u_alu (
        .operand_a  (alu_operand_1),
        .operand_b  (alu_operand_2),
        .alu_op     (alu_op),
        .alu_result (alu_result)
    );

    branch_unit u_branch_unit (
        .pc            (pc),
        .rs1_data      (rs1_data),
        .rs2_data      (rs2_data),
        .imm           (immediate),
        .branch_en     (branch_en),
        .branch_type   (branch_type),
        .branch_taken  (branch_taken),
        .branch_target (branch_target)
    );

    lsu u_lsu (
        .addr         (alu_result),
        .rs2_data     (rs2_data),
        .mem_rd_en    (mem_rd_en),
        .mem_wr_en    (mem_wr_en && !illegal_instr),
        .mem_size     (mem_size),
        .mem_unsigned (mem_unsigned),
        .mem_rdata    (mem_rdata),
        .mem_addr     (mem_addr),
        .mem_wdata    (mem_wdata),
        .mem_wmask    (mem_wmask),
        .mem_ren      (mem_ren),
        .mem_wen      (mem_wen),
        .load_data    (load_data)
    );

    always @(*) begin
        case (reg_wsrc)
            `WB_ALU: wb_data = alu_result;
            `WB_MEM: wb_data = load_data;
            `WB_PC4: wb_data = pc_plus_4;
            `WB_IMM: wb_data = immediate;
            default: wb_data = {`XLEN{1'b0}};
        endcase
    end

    // Keep the decoder's operand-use information visible to lint tools. These
    // signals will be consumed by a future hazard unit in a pipelined version.
    wire unused_decode_hints = rs1_used ^ rs2_used;

endmodule
