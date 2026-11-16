// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M3 - Shared-Memory (Von Neumann) Comparison Design
// File: mem_arbiter.v (Single-port memory arbiter)
// =============================================================================
// Contract Specification (Sections 3.1, 3.2 & Section 5 / M3):
//   CPU side  : exact Section 3.1 instruction port + Section 3.2 data port.
//   Memory side: ONE address/data port into shared_mem_core.
//
//   Arbitration policy (data access has priority over instruction fetch):
//     - Data request present (dmem_re | dmem_we):
//         * the single port is given to the data access
//         * dmem_ready = 1  (data is always served in the same cycle)
//         * imem_ready = 0  (any fetch this cycle is delayed -> CPU holds PC)
//     - No data request:
//         * the single port is given to the instruction fetch
//         * imem_ready = 1
//   The arbiter keeps NO state. Because the CPU must hold imem_addr/imem_req
//   stable while imem_ready = 0 (Section 3.1), a delayed fetch is served
//   automatically on the first cycle without a data request.
//
//   Write rule (Section 3.2): a store takes effect at the rising edge only when
//   dmem_we && dmem_ready -> mem_we = dmem_we & dmem_ready.
//
//   Read values when not valid:
//     - imem_rdata = NOP (32'h0000_0013) when imem_ready = 0 or address unmapped
//     - dmem_rdata = 0 when no load is being served or address unmapped
//   (Contract only requires rdata to be valid when ready = 1; driving fixed
//    values otherwise keeps waveforms clean and X-free.)
// =============================================================================

`timescale 1ns / 1ps

module mem_arbiter (
    // ---------------- CPU instruction port (Section 3.1) ----------------
    input  wire [31:0] imem_addr,
    input  wire        imem_req,
    output wire [31:0] imem_rdata,
    output wire        imem_ready,

    // ---------------- CPU data port (Section 3.2) -----------------------
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire        dmem_re,
    input  wire        dmem_we,
    input  wire [3:0]  dmem_be,
    output wire [31:0] dmem_rdata,
    output wire        dmem_ready,

    // ---------------- Single shared memory port -------------------------
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_be,
    output wire        mem_we,
    input  wire [31:0] mem_rdata,
    input  wire        mem_hit,      // 1 = mem_addr is inside a mapped region

    // ---------------- Status (for counters / debug) ---------------------
    output wire        grant_data,   // 1 = port serves the data access this cycle
    output wire        conflict      // 1 = fetch requested but delayed this cycle
);

    localparam [31:0] NOP = 32'h0000_0013;

    // Any data access (load or store) wants the port
    wire data_req = dmem_re | dmem_we;

    // Priority: data > instruction fetch
    assign grant_data = data_req;
    assign conflict   = imem_req & data_req;

    // Handshake outputs
    assign dmem_ready = 1'b1;          // data always wins -> always served
    assign imem_ready = ~data_req;     // fetch only served when port is free

    // Single-port multiplexing
    assign mem_addr  = data_req ? dmem_addr : imem_addr;
    assign mem_wdata = dmem_wdata;
    assign mem_be    = dmem_be;
    assign mem_we    = dmem_we & dmem_ready;   // Section 3.2 write rule

    // Return paths
    assign imem_rdata = (imem_ready && mem_hit) ? mem_rdata : NOP;
    assign dmem_rdata = (data_req   && mem_hit) ? mem_rdata : 32'h0000_0000;

endmodule
