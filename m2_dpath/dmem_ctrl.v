// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M2 - Data Path
// File: dmem_ctrl.v (Data Memory Controller)
// =============================================================================
// Contract Specification (Section 3.2 & Section 5):
//   Integrates:
//     - Address Decoder (addr_decoder.v)
//     - Data Memory (dmem.v)
//
//   CPU Data Port Interface (Section 3.2):
//     - clk          : System clock
//     - rst_n        : Asynchronous active-low reset
//     - dmem_addr    : 32-bit byte address of data access
//     - dmem_wdata   : 32-bit store data from CPU
//     - dmem_re      : Load request (active-high)
//     - dmem_we      : Store request (active-high)
//     - dmem_be      : 4-bit byte enables (4'b1111 for word access)
//     - dmem_rdata   : 32-bit load data, combinational read
//     - dmem_ready   : 1 = access completes this cycle (always 1 for Harvard)
//
//   Debug Interface:
//     - access_fault : Sticky fault flag raised on invalid address accesses
//
// Behavior & Contract Rules:
//   1. dmem_ready is driven to 1'b1 always (Harvard design zero wait-state).
//   2. If addr_error is high during access:
//        - Store is ignored (memory contents preserved).
//        - Load returns 32'h0000_0000.
//        - access_fault is raised and latched sticky until reset.
//   3. Simultaneous re and we:
//        - Write wins (takes effect at rising clock edge).
//        - Read returns old data (combinational read before edge).
//   4. Byte-enable writes:
//        - Handled cleanly via byte masks (read-modify-write inside dmem).
// =============================================================================

`timescale 1ns / 1ps

module dmem_ctrl #(
    parameter INIT_FILE = "",
    parameter DEPTH     = 1024
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU Data Port (Section 3.2 Contract)
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire        dmem_re,
    input  wire        dmem_we,
    input  wire [3:0]  dmem_be,
    output wire [31:0] dmem_rdata,
    output wire        dmem_ready,

    // Debug Output
    output reg         access_fault
);

    // Harvard design: dmem_ready is always 1 (single-cycle zero wait-state)
    assign dmem_ready = 1'b1;

    // Internal decoder signals
    wire        sel_dmem;
    wire        sel_imem_region;
    wire        addr_error;
    wire [9:0]  word_index;

    // Instantiate Address Decoder
    addr_decoder decoder_inst (
        .addr            (dmem_addr),
        .sel_dmem        (sel_dmem),
        .sel_imem_region (sel_imem_region),
        .addr_error      (addr_error),
        .word_index      (word_index)
    );

    // Memory write enable:
    // Takes effect at rising clock edge only when dmem_we && dmem_ready && !addr_error
    wire mem_we = dmem_we && dmem_ready && !addr_error;

    // Raw memory read data
    wire [31:0] mem_rdata_raw;

    // Instantiate Data Memory Array
    dmem #(
        .INIT_FILE (INIT_FILE),
        .DEPTH     (DEPTH)
    ) mem_inst (
        .clk   (clk),
        .addr  (word_index),
        .wdata (dmem_wdata),
        .we    (mem_we),
        .be    (dmem_be),
        .rdata (mem_rdata_raw)
    );

    // Read Data Output:
    // Returns 32'h0000_0000 on invalid address access or when dmem_re is inactive.
    // When dmem_re is active and address is valid, returns combinational memory data.
    // In case of simultaneous re and we, returns the old data currently in memory.
    assign dmem_rdata = (dmem_re && !addr_error) ? mem_rdata_raw : 32'h0000_0000;

    // Sticky Access Fault:
    // Asserted when an access (read or write) is attempted to an out-of-range address.
    // Remains asserted until system reset (rst_n asserted low).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            access_fault <= 1'b0;
        end else begin
            if ((dmem_re || dmem_we) && addr_error) begin
                access_fault <= 1'b1;
            end
        end
    end

endmodule
