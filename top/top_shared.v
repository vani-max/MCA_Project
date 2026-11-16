
`timescale 1ns/1ps

module top_shared #(
    parameter PROGRAM_FILE = "",
    parameter DATA_FILE    = ""
)(
    input  wire clk,
    input  wire rst_n,
    output wire halt,
    output wire [31:0] conflict_count,
    output wire access_fault
);

    // CPU instruction interface
    wire [31:0] imem_addr;
    wire        imem_req;
    wire [31:0] imem_rdata;
    wire        imem_ready;

    // CPU data interface
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_re;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_rdata;
    wire        dmem_ready;

    // ------------------------------------------------
    // M4: Processor Core
    // ------------------------------------------------

    cpu_core cpu_inst (
        .clk        (clk),
        .rst_n      (rst_n),

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

        .halt       (halt)
    );

    // ------------------------------------------------
    // M3: Shared Instruction and Data Memory
    // ------------------------------------------------

    shared_mem #(
        .PROG_FILE (PROGRAM_FILE),
        .DATA_FILE (DATA_FILE)
    ) shared_mem_inst (
        .clk            (clk),
        .rst_n          (rst_n),

        .imem_addr      (imem_addr),
        .imem_req       (imem_req),
        .imem_rdata     (imem_rdata),
        .imem_ready     (imem_ready),

        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_re        (dmem_re),
        .dmem_we        (dmem_we),
        .dmem_be        (dmem_be),
        .dmem_rdata     (dmem_rdata),
        .dmem_ready     (dmem_ready),

        .conflict_count (conflict_count),
        .access_fault   (access_fault)
    );

    // ------------------------------------------------
    // M5: Performance Counters
    // ------------------------------------------------

    perf_counters counters_inst (
        .clk        (clk),
        .rst_n      (rst_n),

        .imem_req   (imem_req),
        .imem_ready (imem_ready),

        .dmem_re    (dmem_re),
        .dmem_we    (dmem_we),
        .dmem_ready (dmem_ready),

        .halt       (halt)
    );

endmodule
