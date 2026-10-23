`include "../../riscv_def.vh"

module lsu (
    // ============================================================
    // From CPU datapath
    // ============================================================
    input  [`XLEN-1:0] addr,
    input  [`XLEN-1:0] rs2_data,

    // ============================================================
    // From Control Unit
    // ============================================================
    input               mem_rd_en,
    input               mem_wr_en,
    input  [1:0]        mem_size,
    input               mem_unsigned,

    // ============================================================
    // From Data Memory
    // ============================================================
    input  [`XLEN-1:0] mem_rdata,

    // ============================================================
    // To Data Memory
    // ============================================================
    output     [`XLEN-1:0] mem_addr,
    output reg [`XLEN-1:0] mem_wdata,
    output reg [3:0]       mem_wmask,
    output                 mem_ren,
    output                 mem_wen,

    // ============================================================
    // To Write Back
    // ============================================================
    output reg [`XLEN-1:0] load_data
);


    // ============================================================
    // Memory interface
    // ============================================================

    assign mem_addr = addr;
    assign mem_ren  = mem_rd_en;
    assign mem_wen  = mem_wr_en;


    // ============================================================
    // Store
    // ============================================================

    always @(*) begin

        mem_wmask = 4'b0000;
        mem_wdata = {`XLEN{1'b0}};

        if (mem_wr_en) begin

            case (mem_size)

                // =================================================
                // SB
                // =================================================

                `MEM_BYTE: begin

                    case (addr[1:0])

                        2'b00: begin
                            mem_wmask = 4'b0001;
                            mem_wdata = {24'b0,rs2_data[7:0]};
                        end

                        2'b01: begin
                            mem_wmask = 4'b0010;
                            mem_wdata = {16'b0,rs2_data[7:0],8'b0};
                        end

                        2'b10: begin
                            mem_wmask = 4'b0100;
                            mem_wdata = {8'b0,rs2_data[7:0],16'b0};
                        end

                        2'b11: begin
                            mem_wmask = 4'b1000;
                            mem_wdata = {rs2_data[7:0],24'b0};
                        end

                    endcase

                end


                // =================================================
                // SH
                // =================================================

                `MEM_HALF: begin

                    case (addr[1:0])

                        2'b00: begin
                            mem_wmask = 4'b0011;
                            mem_wdata = {16'b0,rs2_data[15:0]};
                        end

                        2'b10: begin
                            mem_wmask = 4'b1100;
                            mem_wdata = {rs2_data[15:0],16'b0};
                        end

                        default: begin
                            mem_wmask = 4'b0000;
                            mem_wdata = {`XLEN{1'b0}};
                        end

                    endcase

                end


                // =================================================
                // SW
                // =================================================

                `MEM_WORD: begin
                    mem_wmask = (addr[1:0] == 2'b00) ? 4'b1111 : 4'b0000;
                    mem_wdata = (addr[1:0] == 2'b00) ? rs2_data : {`XLEN{1'b0}};
                end


                default: begin
                    mem_wmask = 4'b0000;
                    mem_wdata = {`XLEN{1'b0}};
                end

            endcase

        end
    end


    // ============================================================
    // Load
    // ============================================================

    always @(*) begin

        load_data = {`XLEN{1'b0}};

        if (mem_rd_en) begin

            case (mem_size)

                // =================================================
                // LB / LBU
                // =================================================

                `MEM_BYTE: begin

                    case (addr[1:0])

                        2'b00: begin
                            load_data = (mem_unsigned == 1'b1) ? {24'b0,mem_rdata[7:0]} : {{24{mem_rdata[7]}},mem_rdata[7:0]};
                        end

                        2'b01: begin
                            load_data = (mem_unsigned == 1'b1) ? {24'b0,mem_rdata[15:8]} : {{24{mem_rdata[15]}},mem_rdata[15:8]};
                        end

                        2'b10: begin
                            load_data = (mem_unsigned == 1'b1) ? {24'b0,mem_rdata[23:16]} : {{24{mem_rdata[23]}},mem_rdata[23:16]};
                        end

                        2'b11: begin
                            load_data = (mem_unsigned == 1'b1) ? {24'b0,mem_rdata[31:24]} : {{24{mem_rdata[31]}},mem_rdata[31:24]};
                        end

                    endcase

                end


                // =================================================
                // LH / LHU
                // =================================================

                `MEM_HALF: begin

                    case (addr[1:0])

                        2'b00: begin
                            load_data = (mem_unsigned == 1'b1) ? {16'b0,mem_rdata[15:0]} : {{16{mem_rdata[15]}},mem_rdata[15:0]};
                        end

                        2'b10: begin
                            load_data = (mem_unsigned == 1'b1) ? {16'b0,mem_rdata[31:16]} : {{16{mem_rdata[31]}},mem_rdata[31:16]};
                        end

                        default: begin
                            load_data = {`XLEN{1'b0}};
                        end

                    endcase

                end


                // =================================================
                // LW
                // =================================================

                `MEM_WORD: begin
                    load_data = (addr[1:0] == 2'b00) ? mem_rdata : {`XLEN{1'b0}};
                end


                default: begin
                    load_data = {`XLEN{1'b0}};
                end

            endcase

        end
    end


endmodule