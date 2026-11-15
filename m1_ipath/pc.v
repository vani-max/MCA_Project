// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M1 - Instruction Path
// File: pc.v (Program Counter)
// =============================================================================
// Contract Specification (Section 5):
//   Ports:
//     - clk           : System clock (rising edge active)
//     - rst_n         : Asynchronous active-low reset
//     - stall         : Active-high stall signal (holds PC)
//     - branch_taken  : Active-high branch/jump redirect signal
//     - branch_target : 32-bit branch target address
//     - pc            : 32-bit current program counter output
//
// Behavior & Priority Rules:
//   1. Reset (rst_n = 0)        -> pc <= 32'h0000_0000
//   2. Stall (stall = 1)        -> pc <= pc (holds value, stall wins over branch)
//   3. Branch (branch_taken = 1)-> pc <= branch_target
//   4. Sequential increment     -> pc <= pc + 32'd4 (word-aligned instruction step)
// =============================================================================

`timescale 1ns / 1ps

module pc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        branch_taken,
    input  wire [31:0] branch_target,
    output reg  [31:0] pc
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0000_0000;
        end else if (stall) begin
            // Stall priority: holds PC when stall=1 (stall + branch priority: stall wins)
            pc <= pc;
        end else if (branch_taken) begin
            // Branch/Jump target redirection
            pc <= branch_target;
        end else begin
            // Sequential instruction execution (+4 bytes per instruction)
            pc <= pc + 32'd4;
        end
    end

endmodule
