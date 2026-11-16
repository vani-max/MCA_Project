// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M3 - Shared-Memory (Von Neumann) Comparison Design
// File: shared_mem.v (single-port memory core + shared-memory top module)
// =============================================================================
// Memory map (Section 4.1) - ONE array, SAME addresses as the Harvard design:
//     0x0000_0000 .. 0x0000_0FFF  instruction region -> array words    0..1023
//     0x1000_0000 .. 0x1000_0FFF  data region        -> array words 1024..2047
//     anything else               unmapped (fetch -> NOP, load -> 0, store ignored)
//   Array index = { addr[28], addr[11:2] }  (11 bits, 2048 words = 8 KB)
//
// Parameters:
//     PROG_FILE : program hex  -> loaded into words    0..1023 ($readmemh)
//     DATA_FILE : data hex     -> loaded into words 1024..2047 ($readmemh)
//   The same *.hex / *_data.hex files used by the Harvard design run unchanged.
//
// Top-level ports (shared_mem): exactly M1 imem_top (Section 3.1) +
//   M2 dmem_ctrl (Section 3.2) combined, so M5 can swap one for the other,
//   plus two analysis/debug outputs:
//     conflict_count : increments every cycle a fetch is delayed by a data access
//     access_fault   : sticky flag, set when a data access hits an unmapped address
// =============================================================================

`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Single-port memory core: one address/data port, synchronous write with byte
// enables, combinational read.
// -----------------------------------------------------------------------------
module shared_mem_core #(
    parameter PROG_FILE = "",
    parameter DATA_FILE = ""
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  be,
    input  wire        we,
    output wire [31:0] rdata,
    output wire        hit
);

    localparam REGION_WORDS = 1024;
    localparam DEPTH        = 2 * REGION_WORDS;   // 2048 words = 8 KB

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        // Instruction half pre-filled with NOP, data half with 0 -> no X values
        for (i = 0; i < REGION_WORDS; i = i + 1) mem[i] = 32'h0000_0013;
        for (i = REGION_WORDS; i < DEPTH; i = i + 1) mem[i] = 32'h0000_0000;

        if (PROG_FILE != "") $readmemh(PROG_FILE, mem, 0, REGION_WORDS - 1);
        if (DATA_FILE != "") $readmemh(DATA_FILE, mem, REGION_WORDS, DEPTH - 1);
    end

    // Address decode
    wire in_imem = (addr[31:12] == 20'h00000);   // 0x0000_0xxx
    wire in_dmem = (addr[31:12] == 20'h10000);   // 0x1000_0xxx
    assign hit   = in_imem | in_dmem;

    wire [10:0] index = {in_dmem, addr[11:2]};

    // Combinational read
    assign rdata = hit ? mem[index] : 32'h0000_0000;

    // Synchronous byte-enabled write (blocked while in reset, ignored if unmapped)
    always @(posedge clk) begin
        if (rst_n && we && hit) begin
            if (be[0]) mem[index][7:0]   <= wdata[7:0];
            if (be[1]) mem[index][15:8]  <= wdata[15:8];
            if (be[2]) mem[index][23:16] <= wdata[23:16];
            if (be[3]) mem[index][31:24] <= wdata[31:24];
        end
    end

endmodule


// -----------------------------------------------------------------------------
// Shared-memory (Von Neumann) top module: arbiter + single-port core + counters
// -----------------------------------------------------------------------------
module shared_mem #(
    parameter PROG_FILE = "",
    parameter DATA_FILE = ""
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU instruction port (Section 3.1)
    input  wire [31:0] imem_addr,
    input  wire        imem_req,
    output wire [31:0] imem_rdata,
    output wire        imem_ready,

    // CPU data port (Section 3.2)
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire        dmem_re,
    input  wire        dmem_we,
    input  wire [3:0]  dmem_be,
    output wire [31:0] dmem_rdata,
    output wire        dmem_ready,

    // Analysis / debug outputs
    output reg  [31:0] conflict_count,
    output reg         access_fault
);

    // Internal single-port signals
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_be;
    wire        mem_we;
    wire [31:0] mem_rdata;
    wire        mem_hit;
    wire        grant_data;
    wire        conflict;

    mem_arbiter u_arb (
        .imem_addr  (imem_addr),
        .imem_req   (imem_req),
        .imem_rdata (imem_rdata),
        .imem_ready (imem_ready),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_re    (dmem_re),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be),
        .dmem_rdata (dmem_rdata),
        .dmem_ready (dmem_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_be     (mem_be),
        .mem_we     (mem_we),
        .mem_rdata  (mem_rdata),
        .mem_hit    (mem_hit),
        .grant_data (grant_data),
        .conflict   (conflict)
    );

    shared_mem_core #(
        .PROG_FILE (PROG_FILE),
        .DATA_FILE (DATA_FILE)
    ) u_core (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (mem_addr),
        .wdata (mem_wdata),
        .be    (mem_be),
        .we    (mem_we),
        .rdata (mem_rdata),
        .hit   (mem_hit)
    );

    // Conflict counter + sticky access fault (active-low asynchronous reset)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            conflict_count <= 32'd0;
            access_fault   <= 1'b0;
        end else begin
            if (conflict)
                conflict_count <= conflict_count + 32'd1;
            if (grant_data && !mem_hit)
                access_fault <= 1'b1;
        end
    end

endmodule
