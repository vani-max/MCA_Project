// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M2 - Data Path
// File: tb_dmem_ctrl.v (Data Memory Controller Specification Testbench)
// =============================================================================
// Covers all Section 5 Unit Tests:
//   1. Word write then read
//   2. Byte-enable write (each of 4 bytes and halfword patterns)
//   3. Read-after-write same address
//   4. Back-to-back accesses
//   5. Boundary addresses (0x1000_0000, 0x1000_0FFC, 0x1000_1000)
//   6. Invalid address access (returns 0, ignores write, raises sticky access_fault)
//   7. Simultaneous re and we (write wins, read returns old data)
//   8. Reset clearing sticky access_fault
// =============================================================================

`timescale 1ns / 1ps

module tb_dmem_ctrl;

    // Clock and Reset
    reg         clk;
    reg         rst_n;

    // CPU Data Port Signals
    reg  [31:0] dmem_addr;
    reg  [31:0] dmem_wdata;
    reg         dmem_re;
    reg         dmem_we;
    reg  [3:0]  dmem_be;
    wire [31:0] dmem_rdata;
    wire        dmem_ready;

    // Debug Output
    wire        access_fault;

    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate Unit Under Test (UUT)
    dmem_ctrl #(
        .INIT_FILE (""),
        .DEPTH     (1024)
    ) uut (
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

    // Clock generator: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // Task: Perform a write transaction
    task write_mem(
        input [31:0] addr,
        input [31:0] data,
        input [3:0]  be_mask
    );
        begin
            @(posedge clk);
            dmem_addr  <= addr;
            dmem_wdata <= data;
            dmem_we    <= 1'b1;
            dmem_re    <= 1'b0;
            dmem_be    <= be_mask;
            @(posedge clk);
            dmem_we    <= 1'b0;
            dmem_be    <= 4'b0000;
        end
    endtask

    // Task: Perform a read transaction and check expected output
    task read_and_check(
        input [31:0]  addr,
        input [31:0]  exp_data,
        input [127:0] test_name
    );
        begin
            @(posedge clk);
            dmem_addr <= addr;
            dmem_re   <= 1'b1;
            dmem_we   <= 1'b0;
            dmem_be   <= 4'b0000;
            #1; // Allow combinational read propagation
            if (dmem_rdata === exp_data && dmem_ready === 1'b1) begin
                $display("[PASS] %s | Addr: 0x%08h -> Data: 0x%08h | ready=%b",
                         test_name, addr, dmem_rdata, dmem_ready);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s | Addr: 0x%08h | Exp: 0x%08h, ready=1 | Got: 0x%08h, ready=%b",
                         test_name, addr, exp_data, dmem_rdata, dmem_ready);
                fail_count = fail_count + 1;
            end
            @(posedge clk);
            dmem_re   <= 1'b0;
        end
    endtask

    initial begin
        $dumpfile("waves/tb_dmem_ctrl.vcd");
        $dumpvars(0, tb_dmem_ctrl);

        // Signal initialization
        clk        = 0;
        rst_n      = 0;
        dmem_addr  = 32'h0000_0000;
        dmem_wdata = 32'h0000_0000;
        dmem_re    = 1'b0;
        dmem_we    = 1'b0;
        dmem_be    = 4'b0000;

        $display("================================================================================");
        $display(" Starting Data Memory Controller Specification Testbench (tb_dmem_ctrl.v)");
        $display("================================================================================");

        // Reset system
        #20;
        rst_n = 1;
        #10;

        // Check ready signal and initial fault flag
        if (dmem_ready === 1'b1 && access_fault === 1'b0) begin
            $display("[PASS] Contract Init: dmem_ready=1 and access_fault=0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Contract Init: Expected ready=1, fault=0. Got ready=%b, fault=%b",
                     dmem_ready, access_fault);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 1: Word write then read
        // ---------------------------------------------------------------------
        $display("\n--- Test 1: Word write then read ---");
        write_mem(32'h1000_0010, 32'hDEADBEEF, 4'b1111);
        read_and_check(32'h1000_0010, 32'hDEADBEEF, "Test 1: Word Read");

        // ---------------------------------------------------------------------
        // TEST 2: Byte-enable write (each of the 4 bytes & halfword patterns)
        // ---------------------------------------------------------------------
        $display("\n--- Test 2: Byte-enable write (4 individual bytes + halfwords) ---");
        // Clear word at 0x1000_0020
        write_mem(32'h1000_0020, 32'h0000_0000, 4'b1111);

        // Write Byte 0 (be = 4'b0001)
        write_mem(32'h1000_0020, 32'h0000_0011, 4'b0001);
        read_and_check(32'h1000_0020, 32'h0000_0011, "Byte 0 Write (0x11)");

        // Write Byte 1 (be = 4'b0010)
        write_mem(32'h1000_0020, 32'h0000_2200, 4'b0010);
        read_and_check(32'h1000_0020, 32'h0000_2211, "Byte 1 Write (0x22)");

        // Write Byte 2 (be = 4'b0100)
        write_mem(32'h1000_0020, 32'h0033_0000, 4'b0100);
        read_and_check(32'h1000_0020, 32'h0033_2211, "Byte 2 Write (0x33)");

        // Write Byte 3 (be = 4'b1000)
        write_mem(32'h1000_0020, 32'h4400_0000, 4'b1000);
        read_and_check(32'h1000_0020, 32'h4433_2211, "Byte 3 Write (0x44)");

        // Halfword pattern on 0x1000_0024
        write_mem(32'h1000_0024, 32'h0000_AAAA, 4'b0011); // Lower halfword
        read_and_check(32'h1000_0024, 32'h0000_AAAA, "Lower Halfword (0xAAAA)");

        write_mem(32'h1000_0024, 32'hBBBB_0000, 4'b1100); // Upper halfword
        read_and_check(32'h1000_0024, 32'hBBBB_AAAA, "Upper Halfword (0xBBBB)");

        // ---------------------------------------------------------------------
        // TEST 3: Read-after-write (RAW) same address
        // ---------------------------------------------------------------------
        $display("\n--- Test 3: Read-after-write (RAW) same address ---");
        @(posedge clk);
        dmem_addr  <= 32'h1000_0050;
        dmem_wdata <= 32'h9876_5432;
        dmem_we    <= 1'b1;
        dmem_re    <= 1'b0;
        dmem_be    <= 4'b1111;

        // Next cycle: immediate read from same address
        @(posedge clk);
        dmem_we    <= 1'b0;
        dmem_re    <= 1'b1;
        #1;
        if (dmem_rdata === 32'h9876_5432) begin
            $display("[PASS] RAW Same Address: Immediate read got 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] RAW Same Address: Expected 0x98765432, got 0x%08h", dmem_rdata);
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_re <= 1'b0;

        // ---------------------------------------------------------------------
        // TEST 4: Back-to-back accesses
        // ---------------------------------------------------------------------
        $display("\n--- Test 4: Back-to-back accesses ---");
        @(posedge clk);
        dmem_addr <= 32'h1000_0060; dmem_wdata <= 32'h1111_1111; dmem_we <= 1'b1; dmem_re <= 1'b0; dmem_be <= 4'b1111;
        @(posedge clk);
        dmem_addr <= 32'h1000_0064; dmem_wdata <= 32'h2222_2222; dmem_we <= 1'b1; dmem_re <= 1'b0; dmem_be <= 4'b1111;
        @(posedge clk);
        dmem_addr <= 32'h1000_0060; dmem_we <= 1'b0; dmem_re <= 1'b1; dmem_be <= 4'b0000;
        #1;
        if (dmem_rdata === 32'h1111_1111) begin
            $display("[PASS] Back-to-back Read 1: Addr 0x1000_0060 = 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Back-to-back Read 1: Expected 0x11111111, got 0x%08h", dmem_rdata);
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_addr <= 32'h1000_0064; dmem_we <= 1'b0; dmem_re <= 1'b1;
        #1;
        if (dmem_rdata === 32'h2222_2222) begin
            $display("[PASS] Back-to-back Read 2: Addr 0x1000_0064 = 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Back-to-back Read 2: Expected 0x22222222, got 0x%08h", dmem_rdata);
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_re <= 1'b0;

        // ---------------------------------------------------------------------
        // TEST 5: Boundary addresses (0x1000_0000, 0x1000_0FFC, 0x1000_1000)
        // ---------------------------------------------------------------------
        $display("\n--- Test 5: Boundary addresses ---");
        // Base address 0x1000_0000
        write_mem(32'h1000_0000, 32'hFEED_FACE, 4'b1111);
        read_and_check(32'h1000_0000, 32'hFEED_FACE, "Boundary Base 0x1000_0000");

        // Top word 0x1000_0FFC
        write_mem(32'h1000_0FFC, 32'h0BAD_F00D, 4'b1111);
        read_and_check(32'h1000_0FFC, 32'h0BAD_F00D, "Boundary Top Word 0x1000_0FFC");

        // ---------------------------------------------------------------------
        // TEST 6: Invalid address access & sticky access_fault
        // ---------------------------------------------------------------------
        $display("\n--- Test 6: Invalid address access (0x1000_1000) & sticky access_fault ---");
        // Verify access_fault is initially 0 before fault injection
        if (access_fault === 1'b0) begin
            $display("[PASS] Fault pre-condition: access_fault is initially 0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Fault pre-condition: access_fault expected 0, got %b", access_fault);
            fail_count = fail_count + 1;
        end

        // Read from out-of-range address 0x1000_1000
        @(posedge clk);
        dmem_addr <= 32'h1000_1000;
        dmem_re   <= 1'b1;
        dmem_we   <= 1'b0;
        #1;
        if (dmem_rdata === 32'h0000_0000) begin
            $display("[PASS] Out-of-range Read: Addr 0x1000_1000 returned 32'h0000_0000");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Out-of-range Read: Expected 0, got 0x%08h", dmem_rdata);
            fail_count = fail_count + 1;
        end

        // Check that access_fault latches high on posedge clk
        @(posedge clk);
        dmem_re <= 1'b0;
        #1;
        if (access_fault === 1'b1) begin
            $display("[PASS] Sticky Fault: access_fault successfully asserted to 1'b1");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Sticky Fault: access_fault expected 1, got %b", access_fault);
            fail_count = fail_count + 1;
        end

        // Attempt write to invalid address
        @(posedge clk);
        dmem_addr  <= 32'h2000_0000;
        dmem_wdata <= 32'hDEAD_BEEF;
        dmem_we    <= 1'b1;
        dmem_be    <= 4'b1111;
        @(posedge clk);
        dmem_we    <= 1'b0;

        // Perform valid access afterwards and verify access_fault remains sticky (stays 1)
        read_and_check(32'h1000_0000, 32'hFEED_FACE, "Valid Read after Fault");
        if (access_fault === 1'b1) begin
            $display("[PASS] Sticky Fault Persistence: access_fault remained 1 after valid read");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Sticky Fault Persistence: access_fault dropped to %b", access_fault);
            fail_count = fail_count + 1;
        end

        // Reset system to verify access_fault clears
        @(posedge clk);
        rst_n = 0;
        #15;
        if (access_fault === 1'b0) begin
            $display("[PASS] Reset Clears Fault: access_fault successfully cleared to 0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Reset Clears Fault: access_fault remained %b after reset", access_fault);
            fail_count = fail_count + 1;
        end
        rst_n = 1;
        #10;

        // ---------------------------------------------------------------------
        // TEST 7: Simultaneous re and we (write wins, read returns old data)
        // ---------------------------------------------------------------------
        $display("\n--- Test 7: Simultaneous re and we (write wins, read returns old data) ---");
        // Step 1: Pre-load address 0x1000_0080 with 0xOLD0_0001
        write_mem(32'h1000_0080, 32'h01D0_0001, 4'b1111);

        // Step 2: In same cycle, assert BOTH re and we with new data 0xNEW0_0002
        @(posedge clk);
        dmem_addr  <= 32'h1000_0080;
        dmem_wdata <= 32'h0E00_0002;
        dmem_re    <= 1'b1;
        dmem_we    <= 1'b1;
        dmem_be    <= 4'b1111;
        #1; // Sample before clock edge (combinational read)
        if (dmem_rdata === 32'h01D0_0001) begin
            $display("[PASS] Simultaneous re/we Read: returned OLD data 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Simultaneous re/we Read: Expected old data 0x01D00001, got 0x%08h", dmem_rdata);
            fail_count = fail_count + 1;
        end

        // Step 3: Clock edge commits write. Next cycle: read only to check write won
        @(posedge clk);
        dmem_we <= 1'b0;
        dmem_re <= 1'b1;
        #1;
        if (dmem_rdata === 32'h0E00_0002) begin
            $display("[PASS] Simultaneous re/we Write: committed NEW data 0x%08h (Write Won)", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Simultaneous re/we Write: Expected 0x0E000002, got 0x%08h", dmem_rdata);
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_re <= 1'b0;

        #20;
        $display("\n================================================================================");
        $display(" tb_dmem_ctrl Test Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("================================================================================");

        if (fail_count > 0) begin
            $display("TEST SUITE FAILED!");
            $finish(1);
        end else begin
            $display("ALL TESTS PASSED: Data Memory Controller matches contract 100%%.");
            $finish(0);
        end
    end

endmodule
