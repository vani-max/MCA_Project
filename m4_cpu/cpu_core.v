// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: cpu_core.v (Top-Level RISC-V Processor Core)
// =============================================================================
// Contract Specification (Sections 3.1, 3.2, 3.3 & Section 5 / M4):
//
//   Instruction Port (Section 3.1):
//     - imem_addr  : 32-bit address of instruction to fetch (= PC)
//     - imem_req   : 1-bit fetch request (CPU wants an instruction this cycle)
//     - imem_rdata : 32-bit instruction word (combinational read)
//     - imem_ready : 1 = rdata valid; 0 = stall fetch and hold PC
//
//   Data Port (Section 3.2):
//     - dmem_addr  : 32-bit byte address of data access
//     - dmem_wdata : 32-bit store data
//     - dmem_re    : Load request
//     - dmem_we    : Store request
//     - dmem_be    : 4-bit byte enables (4'b1111 for word access)
//     - dmem_rdata : 32-bit load data (combinational read)
//     - dmem_ready : 1 = access completes this cycle; 0 = stall CPU
//
//   Performance Counter Tap (Section 3.3):
//     - halt       : Asserted high when HALT (32'h0000_006F) executes
//
// Microarchitecture:
//   2-stage pipelined architecture (Instruction Fetch | Execute & Writeback).
//   - IF: fetches instruction at PC, increments PC when imem_ready=1.
//   - EX: decodes, reads regfile, executes ALU/branch, accesses data memory,
//         and writes back to regfile.
//   - Zero data hazards (single EX stage holds register reads & writebacks).
//   - Correctly handles stalls on imem_ready=0 and dmem_ready=0.
// =============================================================================

`timescale 1ns / 1ps

module cpu_core (
    input  wire        clk,
    input  wire        rst_n,

    // CPU instruction port (Section 3.1)
    output wire [31:0] imem_addr,
    output wire        imem_req,
    input  wire [31:0] imem_rdata,
    input  wire        imem_ready,

    // CPU data port (Section 3.2)
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire        dmem_re,
    output wire        dmem_we,
    output wire [3:0]  dmem_be,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_ready,

    // Status / Performance counter tap (Section 3.3)
    output reg         halt
);

    // =========================================================================
    // Pipeline Registers & Internal Signals
    // =========================================================================

    // Stage 1 (IF) Program Counter
    reg  [31:0] pc;

    // Stage 2 (EX) Pipeline Registers
    reg  [31:0] ex_pc;
    reg  [31:0] ex_instr;
    reg         ex_valid;

    // =========================================================================
    // Stage 1: Instruction Fetch (IF) Interface
    // =========================================================================
    assign imem_addr = pc;
    assign imem_req  = rst_n && !halt;

    // =========================================================================
    // Stage 2: Control Unit & Instruction Decoder
    // =========================================================================
    wire [4:0]  rs1_addr;
    wire [4:0]  rs2_addr;
    wire [4:0]  rd_addr;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j, imm;
    wire [3:0]  alu_op;
    wire        alu_src_b;
    wire        mem_read;
    wire        mem_write;
    wire [3:0]  ctrl_dmem_be;
    wire [1:0]  wb_src;
    wire        reg_write;
    wire        is_branch;
    wire        is_beq;
    wire        is_bne;
    wire        is_jal;
    wire        is_halt;

    control ctrl_inst (
        .instr        (ex_instr),
        .rs1          (rs1_addr),
        .rs2          (rs2_addr),
        .rd           (rd_addr),
        .imm_i        (imm_i),
        .imm_s        (imm_s),
        .imm_b        (imm_b),
        .imm_u        (imm_u),
        .imm_j        (imm_j),
        .imm          (imm),
        .alu_op       (alu_op),
        .alu_src_b    (alu_src_b),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .dmem_be      (ctrl_dmem_be),
        .wb_src       (wb_src),
        .reg_write    (reg_write),
        .is_branch    (is_branch),
        .is_beq       (is_beq),
        .is_bne       (is_bne),
        .is_jal       (is_jal),
        .is_halt      (is_halt)
    );

    // =========================================================================
    // Register File
    // =========================================================================
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] rf_wdata;
    wire        rf_we;

    regfile rf_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs1_data (rs1_data),
        .rs2_addr (rs2_addr),
        .rs2_data (rs2_data),
        .rd_addr  (rd_addr),
        .rd_data  (rf_wdata),
        .rd_we    (rf_we)
    );

    // =========================================================================
    // ALU
    // =========================================================================
    wire [31:0] alu_a = rs1_data;
    wire [31:0] alu_b = alu_src_b ? imm : rs2_data;
    wire [31:0] alu_result;
    wire        alu_zero;

    alu alu_inst (
        .a      (alu_a),
        .b      (alu_b),
        .alu_op (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // =========================================================================
    // Branch / Jump Logic
    // =========================================================================
    wire branch_cond = is_beq ? (rs1_data == rs2_data) :
                       is_bne ? (rs1_data != rs2_data) : 1'b0;

    wire branch_taken = ex_valid && ((is_branch && branch_cond) || is_jal) && !is_halt;
    wire [31:0] branch_target = is_jal ? (ex_pc + imm_j) : (ex_pc + imm_b);

    // =========================================================================
    // Stage 2: Data Memory Interface
    // =========================================================================
    wire ex_mem_access = ex_valid && (mem_read || mem_write);
    wire stall_dmem    = ex_mem_access && !dmem_ready;

    assign dmem_addr  = ex_valid ? (mem_write ? (rs1_data + imm_s) : (rs1_data + imm_i)) : 32'h0000_0000;
    assign dmem_wdata = ex_valid ? rs2_data : 32'h0000_0000;
    assign dmem_re    = ex_valid && mem_read;
    assign dmem_we    = ex_valid && mem_write;
    assign dmem_be    = (dmem_re || dmem_we) ? ctrl_dmem_be : 4'b0000;

    // =========================================================================
    // Writeback Multiplexer & Register File Write Enable
    // =========================================================================
    assign rf_wdata = (wb_src == 2'b01) ? dmem_rdata :
                      (wb_src == 2'b10) ? (ex_pc + 32'd4) :
                      alu_result;

    // Write enable is gated by:
    //   - ex_valid: instruction in EX is valid
    //   - reg_write: instruction specifies writeback
    //   - rd_addr != 0: x0 is never written
    //   - !stall_dmem: memory access must complete before retiring/writing
    //   - !halt: writes disabled once halted
    assign rf_we = ex_valid && reg_write && (rd_addr != 5'd0) && !stall_dmem && !halt;

    // =========================================================================
    // Sequential Pipeline Clocking & Hazard/Stall Control
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc       <= 32'h0000_0000;
            ex_pc    <= 32'h0000_0000;
            ex_instr <= 32'h0000_0013; // RISC-V NOP (addi x0, x0, 0)
            ex_valid <= 1'b0;
            halt     <= 1'b0;
        end else if (halt) begin
            // Core halted: freeze PC and EX pipeline stage
            pc       <= pc;
            ex_valid <= 1'b0;
        end else if (stall_dmem) begin
            // Data Memory stall: hold PC, EX stage, and request signals stable
            pc       <= pc;
            ex_pc    <= ex_pc;
            ex_instr <= ex_instr;
            ex_valid <= ex_valid;
        end else begin
            // EX stage instruction completes this cycle
            if (is_halt) begin
                // HALT instruction executed
                halt     <= 1'b1;
                ex_valid <= 1'b0;
                pc       <= pc;
            end else if (branch_taken) begin
                // Branch taken or JAL: redirect PC to target and insert bubble in EX
                pc       <= branch_target;
                ex_valid <= 1'b0;
                ex_instr <= 32'h0000_0013;
            end else if (!imem_ready) begin
                // Instruction Memory not ready (stall/conflict):
                // Hold PC stable and insert bubble into EX
                pc       <= pc;
                ex_valid <= 1'b0;
                ex_instr <= 32'h0000_0013;
            end else begin
                // Normal sequential instruction fetch
                pc       <= pc + 32'd4;
                ex_pc    <= pc;
                ex_instr <= imem_rdata;
                ex_valid <= 1'b1;
            end
        end
    end

endmodule
