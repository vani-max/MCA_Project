// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: control.v (Instruction Decoder and Control Unit)
// =============================================================================
// Specifications (Section 4.2 & Section 5 / M4):
//   Decodes RV32I subset:
//     - ADD, SUB, AND, OR, ADDI, LW, SW, BEQ, BNE, JAL, LUI
//     - HALT (32'h0000_006F: JAL x0, 0 self-loop)
//   Generates all decoded immediate formats (sign-extended) and control signals.
// =============================================================================

`timescale 1ns / 1ps

module control (
    input  wire [31:0] instr,

    // Register file indices
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,

    // Immediates
    output wire [31:0] imm_i,
    output wire [31:0] imm_s,
    output wire [31:0] imm_b,
    output wire [31:0] imm_u,
    output wire [31:0] imm_j,
    output reg  [31:0] imm,

    // ALU control
    output reg  [3:0]  alu_op,
    output reg         alu_src_b,    // 0: rs2_data, 1: imm

    // Memory control
    output reg         mem_read,     // 1 for LW
    output reg         mem_write,    // 1 for SW
    output wire [3:0]  dmem_be,      // 4'b1111 for word access

    // Writeback control
    output reg  [1:0]  wb_src,       // 0: ALU, 1: MEM (LW), 2: PC+4 (JAL)
    output reg         reg_write,    // 1 if instruction writes to rd

    // Branch / Jump / Halt control
    output wire        is_branch,
    output wire        is_beq,
    output wire        is_bne,
    output wire        is_jal,
    output wire        is_halt
);

    // ALU Operation Codes (matching alu.v)
    localparam ALU_ADD    = 4'b0000;
    localparam ALU_SUB    = 4'b0001;
    localparam ALU_AND    = 4'b0010;
    localparam ALU_OR     = 4'b0011;
    localparam ALU_PASS_B = 4'b0100;
    localparam ALU_SLT    = 4'b0101;

    // Instruction field breakdown
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    assign rd  = instr[11:7];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];

    // Sign-extended immediates
    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u = {instr[31:12], 12'b0};
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // HALT identification (Section 4.2): 32'h0000_006F (JAL x0, 0)
    assign is_halt = (instr == 32'h0000_006F);

    // Opcode classification
    wire op_lui    = (opcode == 7'b0110111);
    wire op_jal    = (opcode == 7'b1101111);
    wire op_branch = (opcode == 7'b1100011);
    wire op_load   = (opcode == 7'b0000011);
    wire op_store  = (opcode == 7'b0100011);
    wire op_imm    = (opcode == 7'b0010011);
    wire op_reg    = (opcode == 7'b0110011);

    assign is_branch = op_branch;
    assign is_beq    = op_branch && (funct3 == 3'b000);
    assign is_bne    = op_branch && (funct3 == 3'b001);
    assign is_jal    = op_jal && !is_halt;

    assign dmem_be   = 4'b1111; // 32-bit word access

    always @(*) begin
        // Default values
        alu_op    = ALU_ADD;
        alu_src_b = 1'b0;
        imm       = imm_i;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_src    = 2'b00; // ALU
        reg_write = 1'b0;

        if (is_halt) begin
            // HALT state: no register or memory write
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
        end else if (op_lui) begin
            alu_op    = ALU_PASS_B;
            alu_src_b = 1'b1;
            imm       = imm_u;
            wb_src    = 2'b00;
            reg_write = (rd != 5'd0);
        end else if (op_jal) begin
            wb_src    = 2'b10; // PC + 4
            reg_write = (rd != 5'd0);
        end else if (op_branch) begin
            alu_op    = ALU_SUB;
            alu_src_b = 1'b0;
            imm       = imm_b;
            reg_write = 1'b0;
        end else if (op_load) begin
            alu_op    = ALU_ADD;
            alu_src_b = 1'b1;
            imm       = imm_i;
            mem_read  = 1'b1;
            wb_src    = 2'b01; // Data Memory read data
            reg_write = (rd != 5'd0);
        end else if (op_store) begin
            alu_op    = ALU_ADD;
            alu_src_b = 1'b1;
            imm       = imm_s;
            mem_write = 1'b1;
            reg_write = 1'b0;
        end else if (op_imm) begin
            // ADDI
            alu_op    = ALU_ADD;
            alu_src_b = 1'b1;
            imm       = imm_i;
            wb_src    = 2'b00;
            reg_write = (rd != 5'd0);
        end else if (op_reg) begin
            // R-type: ADD, SUB, AND, OR
            alu_src_b = 1'b0;
            wb_src    = 2'b00;
            reg_write = (rd != 5'd0);

            case (funct3)
                3'b000:  alu_op = (funct7[5] == 1'b1) ? ALU_SUB : ALU_ADD;
                3'b111:  alu_op = ALU_AND;
                3'b110:  alu_op = ALU_OR;
                3'b010:  alu_op = ALU_SLT;
                default: alu_op = ALU_ADD;
            endcase
        end
    end

endmodule
