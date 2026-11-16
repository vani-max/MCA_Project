
`timescale 1ns/1ps

module top_harvard #(
    parameter PROGRAM_FILE = "",
    parameter DATA_FILE    = ""
)(
    input  wire clk,
    input  wire rst_n,
    output wire halt,
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
    // M1: Instruction Memory
    // ------------------------------------------------

    imem_top #(
        .MEM_FILE (PROGRAM_FILE),
        .DEPTH    (1024)
    ) imem_inst (
        .imem_addr  (imem_addr),
        .imem_req   (imem_req),
        .imem_rdata (imem_rdata),
        .imem_ready (imem_ready)
    );

    // ------------------------------------------------
    // M2: Data Memory Controller
    // ------------------------------------------------

    dmem_ctrl #(
        .INIT_FILE (DATA_FILE),
        .DEPTH     (1024)
    ) dmem_inst (
        .clk          (clk),
        .rst_n        (rst_n),

        .dmem_addr    (dmem_addr),
        .dmem_wdata   (dmem_wdata),
        .dmem_re      (dmem_re),
        .dmem_we      (dmem_we),
        .dmem_be      (dmem_be),
        .dmem_rdata   (dmem_rdata),
        .dmem_ready   (dmem_ready),

        .access_fault (access_fault)
    );

    // ------------------------------------------------
    // M5: Performance Counters
    // ------------------------------------------------

    perf_counters counters_inst (
        .clk       (clk),
        .rst_n     (rst_n),

        .imem_req  (imem_req),
        .imem_ready(imem_ready),

        .dmem_re   (dmem_re),
        .dmem_we   (dmem_we),
        .dmem_ready(dmem_ready),

        .halt      (halt)
    );

endmodule
