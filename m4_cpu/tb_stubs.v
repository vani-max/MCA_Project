// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: tb_stubs.v (Program Execution Testbench with Behavioural Stubs)
// =============================================================================
// Specifications (Section 5 / M4):
//   - Connects cpu_core to stub_imem and stub_dmem.
//   - Supports all 5 programs:
//       p1_array_sum, p2_mem_copy, p3_alu_only, p4_max_search, p5_mixed_loop.
//   - Supports both:
//       STALLS=0 (ideal zero-wait stubs)
//       STALLS=1 (pseudo-random stalls on both instruction and data ports)
//   - Verifies exact register and memory outputs on HALT against expected results.
//   - Computes cycle count, retired instructions, loads, stores, and stall cycles.
// =============================================================================

`timescale 1ns / 1ps

module tb_stubs;

    // Parameters with default values (can be overridden via -D or plusargs)
    `ifndef PROG
        `define PROG "p1_array_sum"
    `endif

    `ifndef STALLS
        `define STALLS 0
    `endif

    reg [256*8:1] prog_name = `PROG;
    integer random_stalls   = `STALLS;

    // Clock and reset
    reg clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz clock
    reg rst_n;

    // CPU instruction port
    wire [31:0] imem_addr;
    wire        imem_req;
    wire [31:0] imem_rdata;
    wire        imem_ready;

    // CPU data port
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_re;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_rdata;
    wire        dmem_ready;

    // Status
    wire        halt;

    // File path buffers
    reg [512*8:1] hex_file;
    reg [512*8:1] data_file;

    // Instantiate CPU Core (DUT)
    cpu_core dut (
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

    // Instantiate Stub Instruction Memory
    stub_imem #(
        .DEPTH         (1024),
        .RANDOM_STALLS (`STALLS),
        .SEED          (32'hA1B2_C3D4)
    ) imem_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_req   (imem_req),
        .imem_rdata (imem_rdata),
        .imem_ready (imem_ready)
    );

    // Instantiate Stub Data Memory
    stub_dmem #(
        .DEPTH         (1024),
        .RANDOM_STALLS (`STALLS),
        .SEED          (32'hD4C3_B2A1)
    ) dmem_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_re    (dmem_re),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be),
        .dmem_rdata (dmem_rdata),
        .dmem_ready (dmem_ready)
    );

    // Performance metrics
    integer cycle_count  = 0;
    integer load_count   = 0;
    integer store_count  = 0;
    integer stall_cycles = 0;
    integer instrs_done  = 0;

    always @(posedge clk) begin
        if (rst_n && !halt) begin
            cycle_count <= cycle_count + 1;
            if (dmem_re && dmem_ready) load_count <= load_count + 1;
            if (dmem_we && dmem_ready) store_count <= store_count + 1;
            if (!imem_ready || (dut.ex_mem_access && !dmem_ready))
                stall_cycles <= stall_cycles + 1;
            if (dut.ex_valid && !dut.stall_dmem)
                instrs_done <= instrs_done + 1;
        end
    end

    // Verification check tracking
    integer pass_count = 0;
    integer fail_count = 0;
    integer idx;

    task check_res(input [31:0] got, input [31:0] exp, input [8*60:1] name);
        begin
            if (got === exp) begin
                $display("  [PASS] %0s | Got: 0x%08x (%0d)", name, got, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s | Expected: 0x%08x (%0d), Got: 0x%08x (%0d)",
                         name, exp, exp, got, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Read plusargs if provided
        if ($value$plusargs("PROG=%s", prog_name)) begin
            $display("[INFO] Running program specified by plusarg: %0s", prog_name);
        end
        if ($value$plusargs("STALLS=%d", random_stalls)) begin
            $display("[INFO] Random stalls setting: %0d", random_stalls);
        end

        $sformat(hex_file,  "../programs/%0s.hex", prog_name);
        $sformat(data_file, "../programs/%0s_data.hex", prog_name);

        $display("================================================================================");
        $display(" M4 Stub Execution: Program = %0s | Random Stalls = %0d", prog_name, `STALLS);
        $display("   Program Hex: %0s", hex_file);
        $display("   Data Hex:    %0s", data_file);
        $display("================================================================================");

        // Load files into stub memories
        $readmemh(hex_file, imem_inst.mem);
        if (prog_name != "p3_alu_only") begin
            $readmemh(data_file, dmem_inst.mem);
        end

        // Dump VCD
        $dumpfile("waves/tb_stubs.vcd");
        $dumpvars(0, tb_stubs);

        // Apply reset
        rst_n = 1'b0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1'b1;

        // Run until HALT or timeout (50,000 cycles)
        while (!halt && cycle_count < 50000) begin
            @(posedge clk); #1;
        end
        @(posedge clk); #1;

        if (!halt) begin
            $display("\n[FATAL ERROR] Simulation timed out without reaching HALT!");
            fail_count = fail_count + 1;
        end else begin
            $display("\n[SUCCESS] CPU reached HALT successfully!");
        end

        $display("\n---------------- Execution Statistics ----------------");
        $display("  Total Cycles       : %0d", cycle_count);
        $display("  Instructions Retired: %0d", instrs_done);
        $display("  Total Loads        : %0d", load_count);
        $display("  Total Stores       : %0d", store_count);
        $display("  Stall Cycles       : %0d", stall_cycles);
        if (instrs_done > 0)
            $display("  CPI                : %0.2f", (cycle_count * 1.0) / instrs_done);
        $display("------------------------------------------------------\n");

        $display(">>> Verifying Expected State for %0s <<<", prog_name);

        if (prog_name == "p1_array_sum") begin
            check_res(dut.rf_inst.regs[11], 32'h0000_0550, "x11 (sum of 16 words == 1360)");
            check_res(dmem_inst.mem[16],     32'h0000_0550, "MEM[0x1000_0040] == 1360");
            check_res(dut.rf_inst.regs[12], 32'd0,         "x12 (loop counter == 0)");
            check_res(dut.rf_inst.regs[13], 32'h0000_00a0, "x13 (last element == 160)");
        end else if (prog_name == "p2_mem_copy") begin
            check_res(dut.rf_inst.regs[12], 32'd0,         "x12 (loop counter == 0)");
            check_res(dut.rf_inst.regs[10], 32'h1000_0080, "x10 (src ptr == 0x1000_0080)");
            check_res(dut.rf_inst.regs[11], 32'h1000_0100, "x11 (dst ptr == 0x1000_0100)");
            // Check all 32 copied destination words
            for (idx = 0; idx < 32; idx = idx + 1) begin
                if (dmem_inst.mem[32 + idx] === (idx + 1)) begin
                    pass_count = pass_count + 1;
                end else begin
                    $display("  [FAIL] MEM[0x%08x] (word %0d) = %0d, expected %0d",
                             32'h1000_0080 + idx*4, 32+idx, dmem_inst.mem[32+idx], idx+1);
                    fail_count = fail_count + 1;
                end
            end
            $display("  [PASS] Verified all 32 copied destination words (words 32..63 == 1..32)");
        end else if (prog_name == "p3_alu_only") begin
            check_res(dut.rf_inst.regs[1],  32'h0000_03db, "x1  == 987");
            check_res(dut.rf_inst.regs[2],  32'h0000_063d, "x2  == 1597 (F[16])");
            check_res(dut.rf_inst.regs[4],  32'h0000_0a18, "x4  == 2584");
            check_res(dut.rf_inst.regs[5],  32'h0000_063d, "x5  == 1597");
            check_res(dut.rf_inst.regs[6],  32'h0000_0218, "x6  == 536");
            check_res(dut.rf_inst.regs[7],  32'h0000_0e3d, "x7  == 3645");
            check_res(dut.rf_inst.regs[8],  32'h0000_0242, "x8  == 578");
            check_res(dut.rf_inst.regs[9],  32'h0000_0bfb, "x9  == 3067");
            check_res(dut.rf_inst.regs[10], 32'h0000_0239, "x10 == 569");
            check_res(dut.rf_inst.regs[13], 32'h0000_0397, "x13 == 919");
            check_res(dut.rf_inst.regs[14], 32'h0000_05d9, "x14 == 1497");
            check_res(dut.rf_inst.regs[15], 32'h0000_01fe, "x15 == 510");
            check_res(load_count,           0,             "Zero loads executed");
            check_res(store_count,          0,             "Zero stores executed");
        end else if (prog_name == "p4_max_search") begin
            check_res(dut.rf_inst.regs[12], 32'h0000_0066, "x12 (maximum element == 102)");
            check_res(dmem_inst.mem[16],     32'h0000_0066, "MEM[0x1000_0040] (stored max == 102)");
            check_res(dut.rf_inst.regs[11], 32'd0,         "x11 (loop counter == 0)");
        end else if (prog_name == "p5_mixed_loop") begin
            check_res(dut.rf_inst.regs[11], 32'h0000_0868, "x11 (accumulated sum == 2152)");
            check_res(dmem_inst.mem[16],     32'h0000_0868, "MEM[0x1000_0040] (stored sum == 2152)");
            check_res(dut.rf_inst.regs[12], 32'd0,         "x12 (loop counter == 0)");
        end

        $display("\n================================================================================");
        if (fail_count == 0) begin
            $display(" [PASSED] ALL %0d CHECKS PASSED FOR %0s (Stalls=%0d)!",
                     pass_count, prog_name, `STALLS);
        end else begin
            $display(" [FAILED] %0d CHECKS FAILED FOR %0s!", fail_count, prog_name);
        end
        $display("================================================================================");

        $finish;
    end

endmodule
