// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M1 - Instruction Path
// File: tb_imem.v (Unit Testbench for Instruction Memory)
// =============================================================================
// Contract Specification (Section 4.1 & Section 5):
//   Tests required:
//     1. Read first word (addr = 0x0000_0000)
//     2. Read sequentially across 16-word loaded test program
//     3. Read last word in 4KB memory space (addr = 0x0000_0FFC, word 1023)
//     4. Read uninitialized space within 4KB (pre-initialized NOP = 0x0000_0013)
//     5. Read boundary out-of-range address (addr = 0x0000_1000, 4KB boundary)
//     6. Read out-of-range data memory space (addr = 0x1000_0000)
//     7. Read high out-of-range address (addr = 0xFFFF_FFF0)
//     8. Rapid back-to-back combinational reads
//     9. Verification that no 'X' or 'Z' values ever occur
// =============================================================================

`timescale 1ns / 1ps

module tb_imem;

    // Testbench signals
    reg  [31:0] addr;
    wire [31:0] rdata;

    // Error and test counters
    integer tests_passed = 0;
    integer tests_failed = 0;

    // Instantiate Unit Under Test (UUT)
    imem #(
        .MEM_FILE("prog_test.hex"),
        .DEPTH(1024)
    ) uut (
        .addr(addr),
        .rdata(rdata)
    );

    // Verification task
    task check_rdata(input [31:0] expected, input [8*50:1] test_name);
        begin
            #1; // Allow combinational propagation
            if (rdata === expected) begin
                $display("[PASS] %s | Addr: 0x%08h | Expected: 0x%08h | Got: 0x%08h",
                         test_name, addr, expected, rdata);
                tests_passed = tests_passed + 1;
            end else begin
                $display("[FAIL] %s | Addr: 0x%08h | Expected: 0x%08h | Got: 0x%08h",
                         test_name, addr, expected, rdata);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    initial begin
        // Waveform dump setup
        $dumpfile("waves/tb_imem.vcd");
        $dumpvars(0, tb_imem);

        $display("================================================================");
        $display("  Project 9 - M1: Unit Testbench for Instruction Memory (imem.v) ");
        $display("================================================================");

        addr = 32'h0000_0000;
        #5;

        // -------------------------------------------------------------
        // Test 1: First word read (0x0000_0000)
        // -------------------------------------------------------------
        addr = 32'h0000_0000;
        check_rdata(32'h0050_0093, "1. First word (addi x1, x0, 5)");

        // -------------------------------------------------------------
        // Test 2: Sequential reads from loaded 16-word hex file
        // -------------------------------------------------------------
        addr = 32'h0000_0004; check_rdata(32'h00a0_0113, "2a. Word 1 (addi x2, x0, 10)");
        addr = 32'h0000_0008; check_rdata(32'h0020_81b3, "2b. Word 2 (add x3, x1, x2)");
        addr = 32'h0000_000C; check_rdata(32'h4011_8233, "2c. Word 3 (sub x4, x3, x1)");
        addr = 32'h0000_0010; check_rdata(32'h0020_f2b3, "2d. Word 4 (and x5, x1, x2)");
        addr = 32'h0000_0014; check_rdata(32'h0020_e333, "2e. Word 5 (or x6, x1, x2)");
        addr = 32'h0000_0018; check_rdata(32'h0000_2383, "2f. Word 6 (lw x7, 0(x0))");
        addr = 32'h0000_001C; check_rdata(32'h0070_2023, "2g. Word 7 (sw x7, 0(x0))");
        addr = 32'h0000_0020; check_rdata(32'h0020_8463, "2h. Word 8 (beq x1, x2)");
        addr = 32'h0000_0024; check_rdata(32'h0020_9463, "2i. Word 9 (bne x1, x2)");
        addr = 32'h0000_0028; check_rdata(32'h00c0_00ef, "2j. Word 10 (jal x1)");
        addr = 32'h0000_002C; check_rdata(32'h0000_0013, "2k. Word 11 (nop)");
        addr = 32'h0000_0030; check_rdata(32'h0010_0093, "2l. Word 12 (addi x1, x0, 1)");
        addr = 32'h0000_0034; check_rdata(32'h0020_0113, "2m. Word 13 (addi x2, x0, 2)");
        addr = 32'h0000_0038; check_rdata(32'h0030_0193, "2n. Word 14 (addi x3, x0, 3)");
        addr = 32'h0000_003C; check_rdata(32'h0000_006f, "2o. Word 15 (HALT / jal x0, 0)");

        // -------------------------------------------------------------
        // Test 3: Uninitialized words within 4KB range (pre-filled NOPs)
        // -------------------------------------------------------------
        addr = 32'h0000_0040; check_rdata(32'h0000_0013, "3a. Word 16 (NOP pre-init)");
        addr = 32'h0000_0100; check_rdata(32'h0000_0013, "3b. Word 64 (NOP pre-init)");

        // -------------------------------------------------------------
        // Test 4: Last word of 4KB space (addr = 0x0000_0FFC, index 1023)
        // -------------------------------------------------------------
        addr = 32'h0000_0FFC;
        check_rdata(32'h0000_0013, "4. Last word in 4KB IMEM space (idx 1023)");

        // -------------------------------------------------------------
        // Test 5: Boundary out-of-range address (0x0000_1000 = 4096 bytes)
        // -------------------------------------------------------------
        addr = 32'h0000_1000;
        check_rdata(32'h0000_0013, "5. Boundary out-of-range (0x0000_1000 -> NOP)");

        // -------------------------------------------------------------
        // Test 6: Higher out-of-range addresses
        // -------------------------------------------------------------
        addr = 32'h0000_2000;
        check_rdata(32'h0000_0013, "6a. Out-of-range 0x0000_2000 -> NOP");

        addr = 32'h1000_0000; // Data memory base address
        check_rdata(32'h0000_0013, "6b. Data region address 0x1000_0000 -> NOP");

        addr = 32'hFFFF_FFF0;
        check_rdata(32'h0000_0013, "6c. High address 0xFFFF_FFF0 -> NOP");

        // -------------------------------------------------------------
        // Test 7: Back-to-back combinational reads
        // -------------------------------------------------------------
        #2; addr = 32'h0000_0000; check_rdata(32'h0050_0093, "7a. Fast read word 0");
        #2; addr = 32'h0000_0008; check_rdata(32'h0020_81b3, "7b. Fast read word 2");
        #2; addr = 32'h0000_003C; check_rdata(32'h0000_006f, "7c. Fast read word 15");
        #2; addr = 32'h1000_0004; check_rdata(32'h0000_0013, "7d. Fast read out-of-range");

        #10;
        $display("----------------------------------------------------------------");
        $display("Test Summary: %0d PASSED, %0d FAILED", tests_passed, tests_failed);
        if (tests_failed == 0) begin
            $display(">>> ALL IMEM UNIT TESTS COMPLETED SUCCESSFULLY! <<<");
        end else begin
            $display(">>> SOME IMEM UNIT TESTS FAILED! <<<");
        end
        $display("================================================================");
        $finish;
    end

endmodule
