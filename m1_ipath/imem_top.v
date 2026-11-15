// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M1 - Instruction Path
// File: imem_top.v (Section 3.1 Contract Wrapper for Instruction Memory)
// =============================================================================
// Contract Specification (Section 3.1 & Section 7):
//   Provides exact CPU-side instruction port signals for Harvard design integration:
//     - imem_addr  : 32-bit address from CPU
//     - imem_req   : 1-bit instruction request from CPU
//     - imem_rdata : 32-bit instruction word returned to CPU
//     - imem_ready : 1-bit ready flag (tied to 1'b1 for Harvard design)
// =============================================================================

`timescale 1ns / 1ps

module imem_top #(
    parameter MEM_FILE = "",
    parameter DEPTH    = 1024
)(
    input  wire [31:0] imem_addr,
    input  wire        imem_req,   // Combinational memory serves request in same cycle
    output wire [31:0] imem_rdata,
    output wire        imem_ready  // Harvard architecture: always ready (no stalls)
);

    // Harvard design contract rule (Section 3): imem_ready is always 1
    assign imem_ready = 1'b1;

    // Instantiate core instruction memory
    imem #(
        .MEM_FILE(MEM_FILE),
        .DEPTH(DEPTH)
    ) u_imem (
        .addr(imem_addr),
        .rdata(imem_rdata)
    );

endmodule
