// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M1 - Instruction Path
// File: ipath.v (Integrated Instruction Path Top Module)
// =============================================================================
// Description:
//   Connects the Program Counter (pc.v) and the Instruction Memory (imem.v)
//   to provide the complete Harvard instruction fetch subsystem.
//
// Ports:
//   - clk           : System clock
//   - rst_n         : Asynchronous active-low reset
//   - stall         : CPU / memory pipeline stall input
//   - branch_taken  : Branch / Jump redirect flag
//   - branch_target : Branch / Jump destination PC
//   - pc            : Current instruction byte address (= imem_addr)
//   - instr         : Current fetched instruction word (= imem_rdata)
//   - imem_ready    : Instruction fetch ready flag (= 1'b1 in Harvard)
// =============================================================================

`timescale 1ns / 1ps

module ipath #(
    parameter MEM_FILE = "",
    parameter DEPTH    = 1024
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        branch_taken,
    input  wire [31:0] branch_target,
    output wire [31:0] pc,
    output wire [31:0] instr,
    output wire        imem_ready
);

    // Harvard architecture: instruction memory ready is always 1 (combinational read)
    assign imem_ready = 1'b1;

    // 1. Program Counter instance
    pc u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .pc(pc)
    );

    // 2. Instruction Memory instance
    imem #(
        .MEM_FILE(MEM_FILE),
        .DEPTH(DEPTH)
    ) u_imem (
        .addr(pc),
        .rdata(instr)
    );

endmodule
