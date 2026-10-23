// `ifndef RV32I_DEFS_VH
// `define RV32I_DEFS_VH




// // 指令集长度
// `define  XLEN  32

// // ALU数据源定义
// `define ALUSRC_RS1  2'd0
// `define ALUSRC_RS2  2'd1
// `define ALUSRC_IMM  2'd2
// `define ALUSRC_PC   2'd3



// // instr types
// `define I_TYPE     3'b000
// `define S_TYPE     3'b001
// `define B_TYPE     3'b010
// `define U_TYPE     3'b011
// `define J_TYPE     3'b100
// `define R_TYPE     3'b101
// `define CSR_TYPE   3'b110
// `define NONE_TYPE  3'b111   


// // major opecode
// `define OPCODE_LOAD      7'b0000011
// `define OPCODE_STORE     7'b0100011

// `define OPCODE_OP_IMM    7'b0010011
// `define OPCODE_OP        7'b0110011

// `define OPCODE_LUI       7'b0110111
// `define OPCODE_AUIPC     7'b0010111

// `define OPCODE_BRANCH    7'b1100011
// `define OPCODE_JALR      7'b1100111
// `define OPCODE_JAL       7'b1101111

// `define OPCODE_MISC_MEM  7'b0001111
// `define OPCODE_SYSTEM    7'b1110011


// // 基本指令集

// `define    LUI           6'd0                                    
// `define    AUIPC         6'd1                                     
// `define    JAL           6'd2                                    
// `define    JALR          6'd3                                      
// `define    BEQ           6'd4                                     
// `define    BNE           6'd5                                     
// `define    BLT           6'd6                                    
// `define    BGE           6'd7                                    
// `define    BLTU          6'd8                                     
// `define    BGEU          6'd9                                     
// `define    LB            6'd10                          
// `define    LH            6'd11                             
// `define    LW            6'd12                         
// `define    LBU           6'd13                          
// `define    LHU           6'd14                          
// `define    SB            6'd15                         
// `define    SH            6'd16                         
// `define    SW            6'd17                         
// `define    ADDI          6'd18                           
// `define    SLTI          6'd19                           
// `define    SLTIU         6'd20                           
// `define    XORI          6'd21                          
// `define    ORI           6'd22                         
// `define    ANDI          6'd23                          
// `define    SLLI          6'd24                          
// `define    SRLI          6'd25                          
// `define    SRAI          6'd26                          
// `define    ADD           6'd27                         
// `define    SUB           6'd28                         
// `define    SLL           6'd29                                                   
// `define    SLT           6'd30                              
// `define    SLTU          6'd31                               
// `define    XOR           6'd32                         
// `define    SRL           6'd33                         
// `define    SRA           6'd34                         
// `define    OR            6'd35                        
// `define    AND           6'd36                         
// `define    FENCE         6'd37                           
// `define    FENCEI        6'd38                             
// `define    ECALL         6'd39                           
// `define    EBREAK        6'd40                         
// `define    CSRRW         6'd41                        
// `define    CSRRS         6'd42                        
// `define    CSRRC         6'd43                        
// `define    CSRRWI        6'd44                         
// `define    CSRRSI        6'd45                          
// `define    CSRRCI        6'd46                         
                

// `define    ERROR_INSTR   6'd63 

// `endif



// // 

`ifndef RV32I_DEFS_VH
`define RV32I_DEFS_VH


// ============================================================================
//  Basic CPU Parameters
// ============================================================================

`define XLEN            32
`define INSTR_WIDTH     32
`define REG_ADDR_WIDTH   5
`define CSR_ADDR_WIDTH  12

`define REG_ZERO        5'd0

// ADDI x0, x0, 0
// 常用于流水线插入 bubble / NOP
`define NOP             32'h0000_0013


// ============================================================================
//  PC source
// ============================================================================

`define PC_NEXT        2'b00
`define PC_JALR        2'b01
`define PC_JAL         2'b10




// ============================================================================
//  Common Enable / Disable
// ============================================================================

`define ENABLE          1'b1
`define DISABLE         1'b0


// ============================================================================
//  Instruction Format
//
//  注意：这里描述的是“编码格式”，不是 opcode。
// ============================================================================

`define I_TYPE          3'b000
`define S_TYPE          3'b001
`define B_TYPE          3'b010
`define U_TYPE          3'b011
`define J_TYPE          3'b100
`define R_TYPE          3'b101

// CSR immediate:
// CSRRWI / CSRRSI / CSRRCI 的立即数来自 instr[19:15]
`define CSR_TYPE        3'b110

`define NONE_TYPE       3'b111


// ============================================================================
//  RISC-V Major Opcode
// ============================================================================

// Load
`define OPCODE_LOAD         7'b0000011
// Store
`define OPCODE_STORE        7'b0100011
// Immediate arithmetic / logic
`define OPCODE_OP_IMM       7'b0010011
// Register arithmetic / logic
`define OPCODE_OP           7'b0110011
// Upper immediate
`define OPCODE_LUI          7'b0110111
`define OPCODE_AUIPC        7'b0010111
// Branch
`define OPCODE_BRANCH       7'b1100011
// Jump
`define OPCODE_JALR         7'b1100111
`define OPCODE_JAL          7'b1101111
// Fence
`define OPCODE_MISC_MEM     7'b0001111
// ECALL / EBREAK / CSR
`define OPCODE_SYSTEM       7'b1110011
// ============================================================================
//  funct3 - BRANCH
// ============================================================================
`define F3_BEQ              3'b000
`define F3_BNE              3'b001
`define F3_BLT              3'b100
`define F3_BGE              3'b101
`define F3_BLTU             3'b110
`define F3_BGEU             3'b111
// ============================================================================
//  funct3 - LOAD
// ============================================================================
`define F3_LB               3'b000
`define F3_LH               3'b001
`define F3_LW               3'b010
`define F3_LBU              3'b100
`define F3_LHU              3'b101
// ============================================================================
//  funct3 - STORE
// ============================================================================
`define F3_SB               3'b000
`define F3_SH               3'b001
`define F3_SW               3'b010
// ============================================================================
//  funct3 - OP / OP-IMM
//
//  OP 和 OP-IMM 的 funct3 大部分是共用的。
// ============================================================================

`define F3_ADD_SUB          3'b000
`define F3_SLL              3'b001
`define F3_SLT              3'b010
`define F3_SLTU             3'b011
`define F3_XOR              3'b100
`define F3_SRL_SRA          3'b101
`define F3_OR               3'b110
`define F3_AND              3'b111


// ============================================================================
//  funct3 - JALR
// ============================================================================

`define F3_JALR             3'b000


// ============================================================================
//  funct3 - MISC-MEM
// ============================================================================

`define F3_FENCE            3'b000
`define F3_FENCEI           3'b001


// ============================================================================
//  funct3 - SYSTEM / CSR
// ============================================================================

// ECALL / EBREAK
`define F3_SYSTEM           3'b000

// CSR register operation
`define F3_CSRRW            3'b001
`define F3_CSRRS            3'b010
`define F3_CSRRC            3'b011

// CSR immediate operation
`define F3_CSRRWI           3'b101
`define F3_CSRRSI           3'b110
`define F3_CSRRCI           3'b111


// ============================================================================
//  funct7
// ============================================================================

// ADD / SLL / SLT / SLTU / XOR / SRL / OR / AND
`define FUNCT7_NORMAL       7'b0000000

// SUB / SRA
`define FUNCT7_SUB_SRA      7'b0100000


// ============================================================================
//  SYSTEM instruction imm[11:0]
// ============================================================================

`define SYS_ECALL           12'h000
`define SYS_EBREAK          12'h001


// ============================================================================
//  Internal Instruction ID
//
//  这是 CPU 内部使用的 instruction_id。
//  和真正机器指令编码没有直接关系。
// ============================================================================

// -------------------- U / J --------------------

`define LUI                 6'd0
`define AUIPC               6'd1

`define JAL                 6'd2
`define JALR                6'd3


// -------------------- Branch --------------------

`define BEQ                 6'd4
`define BNE                 6'd5
`define BLT                 6'd6
`define BGE                 6'd7
`define BLTU                6'd8
`define BGEU                6'd9


// -------------------- Load --------------------

`define LB                  6'd10
`define LH                  6'd11
`define LW                  6'd12
`define LBU                 6'd13
`define LHU                 6'd14


// -------------------- Store --------------------

`define SB                  6'd15
`define SH                  6'd16
`define SW                  6'd17


// -------------------- OP-IMM --------------------

`define ADDI                6'd18
`define SLTI                6'd19
`define SLTIU               6'd20
`define XORI                6'd21
`define ORI                 6'd22
`define ANDI                6'd23

`define SLLI                6'd24
`define SRLI                6'd25
`define SRAI                6'd26


// -------------------- OP --------------------

`define ADD                 6'd27
`define SUB                 6'd28
`define SLL                 6'd29
`define SLT                 6'd30
`define SLTU                6'd31
`define XOR                 6'd32
`define SRL                 6'd33
`define SRA                 6'd34
`define OR                  6'd35
`define AND                 6'd36


// -------------------- Fence --------------------

`define FENCE               6'd37
`define FENCEI              6'd38


// -------------------- System --------------------

`define ECALL               6'd39
`define EBREAK              6'd40


// -------------------- CSR --------------------

`define CSRRW               6'd41
`define CSRRS               6'd42
`define CSRRC               6'd43

`define CSRRWI              6'd44
`define CSRRSI              6'd45
`define CSRRCI              6'd46

`define MRET                6'd47


// 非法 / 未识别指令
`define INST_INVALID        6'd63


// ============================================================================
//  ALU Operand Source
//
//  如果你的 ALU 两个输入端都使用相同编码的 mux，
//  这组定义可以直接用于 alu_src1 / alu_src2。
// ============================================================================

`define ALUSRC1_RS1          2'd0
`define ALUSRC1_PC           2'd1



`define ALUSRC2_RS2          2'd0
`define ALUSRC2_IMM          2'd1

// ============================================================================
//  ALU Operation
// ============================================================================

`define ALU_ADD             4'd0
`define ALU_SUB             4'd1

`define ALU_SLL             4'd2
`define ALU_SLT             4'd3
`define ALU_SLTU            4'd4

`define ALU_XOR             4'd5
`define ALU_SRL             4'd6
`define ALU_SRA             4'd7

`define ALU_OR              4'd8
`define ALU_AND             4'd9

// 某些数据通路中用于直接传递 operand
`define ALU_PASS            4'd10

`define ALU_NOP             4'd15


// ============================================================================
//  Register Write Back Source
//
//                  WB mux
//
//      ALU result ----┐
//      Memory data ---|
//      PC + 4 --------|----> Register File
//      CSR data ------|
// ============================================================================

`define WB_ALU              3'b000
`define WB_MEM              3'b001
`define WB_PC4              3'b010
`define WB_CSR              3'b011
`define WB_IMM              3'b100

// ============================================================================
//  Memory Operation
// ============================================================================

`define MEM_NONE            2'b00
`define MEM_READ            2'b01
`define MEM_WRITE           2'b10


// ============================================================================
//  Mem   字节读写、半字读写、字读写
// ============================================================================

`define MEM_BYTE            2'b00
`define MEM_HALF            2'b01
`define MEM_WORD            2'b10


// ============================================================================
//  Load Extension
//
//  LB/LH 使用符号扩展
//  LBU/LHU 使用零扩展
// ============================================================================

`define MEM_SIGNED          1'b0
`define MEM_UNSIGNED        1'b1


// ============================================================================
//  Branch / Jump Type
//
//  这组信号可以直接送到 branch unit。
// ============================================================================

`define BR_NONE             4'd0

`define BR_BEQ              4'd1
`define BR_BNE              4'd2

`define BR_BLT              4'd3
`define BR_BGE              4'd4

`define BR_BLTU             4'd5
`define BR_BGEU             4'd6

`define BR_JAL              4'd7
`define BR_JALR             4'd8


// ============================================================================
//  CSR Operand Source
// ============================================================================

// rs1
`define CSR_SRC_RS1         1'b0

// instr[19:15] 中的 zimm
`define CSR_SRC_IMM         1'b1


// ============================================================================
//  CSR Operation
// ============================================================================

`define CSR_OP_NONE         2'b00
`define CSR_OP_WRITE        2'b01
`define CSR_OP_SET          2'b10
`define CSR_OP_CLEAR        2'b11


// ============================================================================
//  Pipeline Control
// ============================================================================

`define PIPE_RUN            2'b00
`define PIPE_STALL          2'b01
`define PIPE_FLUSH          2'b10


// ============================================================================
//  Machine-mode CSR addresses
// ============================================================================

`define CSR_MSTATUS         12'h300
`define CSR_MISA            12'h301
`define CSR_MIE             12'h304
`define CSR_MTVEC           12'h305
`define CSR_MSCRATCH        12'h340
`define CSR_MEPC            12'h341
`define CSR_MCAUSE          12'h342
`define CSR_MTVAL           12'h343
`define CSR_MIP             12'h344
`define CSR_MCYCLE          12'hB00
`define CSR_MINSTRET        12'hB02
`define CSR_MCYCLEH         12'hB80
`define CSR_MINSTRETH       12'hB82
`define CSR_MHARTID         12'hF14


// ============================================================================
//  Exception causes (mcause low bits)
// ============================================================================

`define EXC_INST_MISALIGNED   4'd0
`define EXC_ILLEGAL_INSTR     4'd2
`define EXC_BREAKPOINT        4'd3
`define EXC_LOAD_MISALIGNED   4'd4
`define EXC_STORE_MISALIGNED  4'd6
`define EXC_ECALL_M           4'd11


// ============================================================================
//  mstatus bit positions
// ============================================================================

`define MSTATUS_MIE_BIT        3
`define MSTATUS_MPIE_BIT       7
`define MSTATUS_MPP_LSB        11


`endif