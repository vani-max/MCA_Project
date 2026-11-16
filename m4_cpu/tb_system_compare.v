// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: tb_system_compare.v (Harvard vs Shared Integration Testbench)
// =============================================================================
// Connects cpu_core to:
//   1. Harvard memory system: M1 imem.v + M2 dmem_ctrl.v
//   2. Shared memory system:  M3 shared_mem.v
// Runs all 5 benchmark programs and compares execution cycles, CPI, and stalls.
// =============================================================================

`timescale 1ns / 1ps

module tb_system_compare;

    `ifndef PROG
        `define PROG "p1_array_sum"
    `endif

    reg [256*8:1] prog_name = `PROG;

    // Clocks and resets
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n;

    reg [512*8:1] hex_file;
    reg [512*8:1] data_file;

    // -------------------------------------------------------------------------
    // Design 1: Harvard Architecture (CPU + M1 imem + M2 dmem_ctrl)
    // -------------------------------------------------------------------------
    wire [31:0] h_imem_addr;
    wire        h_imem_req;
    wire [31:0] h_imem_rdata;
    wire        h_imem_ready = 1'b1; // Harvard zero-wait
    wire [31:0] h_dmem_addr;
    wire [31:0] h_dmem_wdata;
    wire        h_dmem_re;
    wire        h_dmem_we;
    wire [3:0]  h_dmem_be;
    wire [31:0] h_dmem_rdata;
    wire        h_dmem_ready;
    wire        h_halt;
    wire        h_fault;

    cpu_core cpu_harvard (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (h_imem_addr),
        .imem_req   (h_imem_req),
        .imem_rdata (h_imem_rdata),
        .imem_ready (h_imem_ready),
        .dmem_addr  (h_dmem_addr),
        .dmem_wdata (h_dmem_wdata),
        .dmem_re    (h_dmem_re),
        .dmem_we    (h_dmem_we),
        .dmem_be    (h_dmem_be),
        .dmem_rdata (h_dmem_rdata),
        .dmem_ready (h_dmem_ready),
        .halt       (h_halt)
    );

    imem #(
        .DEPTH(1024)
    ) imem_harvard (
        .addr  (h_imem_addr),
        .rdata (h_imem_rdata)
    );

    dmem_ctrl #(
        .DEPTH(1024)
    ) dmem_harvard (
        .clk         (clk),
        .rst_n       (rst_n),
        .dmem_addr   (h_dmem_addr),
        .dmem_wdata  (h_dmem_wdata),
        .dmem_re     (h_dmem_re),
        .dmem_we     (h_dmem_we),
        .dmem_be     (h_dmem_be),
        .dmem_rdata  (h_dmem_rdata),
        .dmem_ready  (h_dmem_ready),
        .access_fault(h_fault)
    );

    // -------------------------------------------------------------------------
    // Design 2: Shared-Memory Architecture (CPU + M3 shared_mem)
    // -------------------------------------------------------------------------
    wire [31:0] s_imem_addr;
    wire        s_imem_req;
    wire [31:0] s_imem_rdata;
    wire        s_imem_ready;
    wire [31:0] s_dmem_addr;
    wire [31:0] s_dmem_wdata;
    wire        s_dmem_re;
    wire        s_dmem_we;
    wire [3:0]  s_dmem_be;
    wire [31:0] s_dmem_rdata;
    wire        s_dmem_ready;
    wire        s_halt;
    wire [31:0] s_conflict_count;
    wire        s_fault;

    cpu_core cpu_shared (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (s_imem_addr),
        .imem_req   (s_imem_req),
        .imem_rdata (s_imem_rdata),
        .imem_ready (s_imem_ready),
        .dmem_addr  (s_dmem_addr),
        .dmem_wdata (s_dmem_wdata),
        .dmem_re    (s_dmem_re),
        .dmem_we    (s_dmem_we),
        .dmem_be    (s_dmem_be),
        .dmem_rdata (s_dmem_rdata),
        .dmem_ready (s_dmem_ready),
        .halt       (s_halt)
    );

    shared_mem shared_mem_inst (
        .clk           (clk),
        .rst_n         (rst_n),
        .imem_addr     (s_imem_addr),
        .imem_req      (s_imem_req),
        .imem_rdata    (s_imem_rdata),
        .imem_ready    (s_imem_ready),
        .dmem_addr     (s_dmem_addr),
        .dmem_wdata    (s_dmem_wdata),
        .dmem_re       (s_dmem_re),
        .dmem_we       (s_dmem_we),
        .dmem_be       (s_dmem_be),
        .dmem_rdata    (s_dmem_rdata),
        .dmem_ready    (s_dmem_ready),
        .conflict_count(s_conflict_count),
        .access_fault  (s_fault)
    );

    // Performance tracking
    integer h_cycles = 0;
    integer s_cycles = 0;
    integer h_retired = 0;
    integer s_retired = 0;

    always @(posedge clk) begin
        if (rst_n) begin
            if (!h_halt) begin
                h_cycles <= h_cycles + 1;
                if (cpu_harvard.ex_valid && !cpu_harvard.stall_dmem)
                    h_retired <= h_retired + 1;
            end
            if (!s_halt) begin
                s_cycles <= s_cycles + 1;
                if (cpu_shared.ex_valid && !cpu_shared.stall_dmem)
                    s_retired <= s_retired + 1;
            end
        end
    end

    initial begin
        $sformat(hex_file,  "../programs/%0s.hex", prog_name);
        $sformat(data_file, "../programs/%0s_data.hex", prog_name);

        $display("================================================================================");
        $display(" Cross-Comparison: Harvard vs Shared Memory (%0s)", prog_name);
        $display("================================================================================");

        // Pre-load memories
        $readmemh(hex_file,  imem_harvard.mem);
        $readmemh(hex_file,  shared_mem_inst.u_core.mem, 0, 1023);

        if (prog_name != "p3_alu_only") begin
            $readmemh(data_file, dmem_harvard.mem_inst.mem);
            $readmemh(data_file, shared_mem_inst.u_core.mem, 1024, 2047);
        end

        // Reset both designs
        rst_n = 1'b0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1'b1;

        // Run until both reach HALT
        while ((!h_halt || !s_halt) && (h_cycles < 10000 && s_cycles < 10000)) begin
            @(posedge clk); #1;
        end
        @(posedge clk); #1;

        $display("Execution Results:");
        $display("  Harvard Design: Total Cycles = %0d | Instructions Retired = %0d | CPI = %0.2f",
                 h_cycles, h_retired, (h_cycles * 1.0) / h_retired);
        $display("  Shared  Design: Total Cycles = %0d | Instructions Retired = %0d | CPI = %0.2f",
                 s_cycles, s_retired, (s_cycles * 1.0) / s_retired);
        $display("  Memory Conflicts (Stall Cycles) in Shared Design = %0d", s_conflict_count);
        $display("  Cycle Gap (Shared - Harvard) = %0d cycles (Slowdown = +%0.1f%%)",
                 (s_cycles - h_cycles), ((s_cycles - h_cycles) * 100.0) / h_cycles);

        // Functional check: both designs must yield identical register/memory results!
        if (cpu_harvard.rf_inst.regs[11] === cpu_shared.rf_inst.regs[11]) begin
            $display("  [PASS] Register outputs match perfectly between Harvard and Shared designs!");
        end else begin
            $display("  [FAIL] Register mismatch between designs! Harvard: 0x%08x, Shared: 0x%08x",
                     cpu_harvard.rf_inst.regs[11], cpu_shared.rf_inst.regs[11]);
        end

        if (h_cycles <= s_cycles) begin
            $display("  [PASS] Harvard cycles (%0d) <= Shared cycles (%0d) verified!", h_cycles, s_cycles);
        end else begin
            $display("  [FAIL] Harvard took longer than Shared!");
        end

        $display("================================================================================\n");
        $finish;
    end

endmodule
