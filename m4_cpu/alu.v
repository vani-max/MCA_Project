// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: alu.v (Arithmetic Logic Unit)
// =============================================================================
// Specifications (Section 4.2 & Section 5 / M4):
//   Supports RV32I subset operations:
//     - ADD : Addition (ADD, ADDI, LW address, SW address)
//     - SUB : Subtraction (SUB)
//     - AND : Bitwise AND (AND)
//     - OR  : Bitwise OR (OR)
//     - PASS_B : Pass operand B directly (LUI)
//     - SLT : Set Less Than (signed comparison)
// =============================================================================

`timescale 1ns / 1ps

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] result,
    output wire        zero
);

    // ALU Operation Codes
    localparam ALU_ADD    = 4'b0000;
    localparam ALU_SUB    = 4'b0001;
    localparam ALU_AND    = 4'b0010;
    localparam ALU_OR     = 4'b0011;
    localparam ALU_PASS_B = 4'b0100;
    localparam ALU_SLT    = 4'b0101;

    always @(*) begin
        case (alu_op)
            ALU_ADD:    result = a + b;
            ALU_SUB:    result = a - b;
            ALU_AND:    result = a & b;
            ALU_OR:     result = a | b;
            ALU_PASS_B: result = b;
            ALU_SLT:    result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default:    result = 32'h0000_0000;
        endcase
    end

    assign zero = (result == 32'h0000_0000);

endmodule
