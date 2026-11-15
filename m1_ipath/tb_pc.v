// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M1 - Instruction Path
// File: tb_pc.v (Unit Testbench for Program Counter)
// =============================================================================
// Contract Specification (Section 5):
//   Tests required:
//     1. Reset value (0x0000_0000)
//     2. Sequential increment (+4 each cycle)
//     3. Branch load (loads branch_target when branch_taken=1)
//     4. Stall hold (pc holds previous value when stall=1)
//     5. Stall + branch priority (stall wins when both stall=1 & branch_taken=1)
//     6. Recovery when stall deasserts
//     7. Mid-operation reset
// =============================================================================

`timescale 1ns / 1ps

module tb_pc;

    // Testbench signals
    reg         clk;
    reg         rst_n;
    reg         stall;
    reg         branch_taken;
    reg  [31:0] branch_target;
    wire [31:0] pc;

    // Error and test counters
    integer tests_passed = 0;
    integer tests_failed = 0;

    // Instantiate Unit Under Test (UUT)
    pc uut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .pc(pc)
    );

    // Clock generation: 100 MHz (10ns period, 5ns half-period)
    always #5 clk = ~clk;

    // Task for checking PC value
    task check_pc(input [31:0] expected, input [8*40:1] test_name);
        begin
            if (pc === expected) begin
                $display("[PASS] %s | Expected PC = 0x%08h, Got = 0x%08h", test_name, expected, pc);
                tests_passed = tests_passed + 1;
            end else begin
                $display("[FAIL] %s | Expected PC = 0x%08h, Got = 0x%08h", test_name, expected, pc);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    initial begin
        // Waveform dump setup
        $dumpfile("waves/tb_pc.vcd");
        $dumpvars(0, tb_pc);

        $display("================================================================");
        $display("   Project 9 - M1: Unit Testbench for Program Counter (pc.v)    ");
        $display("================================================================");

        // Initialize signals
        clk           = 0;
        rst_n         = 0;
        stall         = 0;
        branch_taken  = 0;
        branch_target = 32'h0000_0000;

        // -------------------------------------------------------------
        // Test 1: Reset value check
        // -------------------------------------------------------------
        #12; // Wait across rising edge while in reset
        check_pc(32'h0000_0000, "1. Reset value check");

        // Release reset
        @(negedge clk);
        rst_n = 1;

        // -------------------------------------------------------------
        // Test 2: Sequential increment (+4 each cycle)
        // -------------------------------------------------------------
        @(posedge clk); #1;
        check_pc(32'h0000_0004, "2a. Sequential increment cycle 1");

        @(posedge clk); #1;
        check_pc(32'h0000_0008, "2b. Sequential increment cycle 2");

        @(posedge clk); #1;
        check_pc(32'h0000_000C, "2c. Sequential increment cycle 3");

        @(posedge clk); #1;
        check_pc(32'h0000_0010, "2d. Sequential increment cycle 4");

        // -------------------------------------------------------------
        // Test 3: Branch load
        // -------------------------------------------------------------
        @(negedge clk);
        branch_taken  = 1;
        branch_target = 32'h0000_0100;

        @(posedge clk); #1;
        check_pc(32'h0000_0100, "3a. Branch target loaded");

        // Deassert branch_taken, verify sequential increment resumes from target
        @(negedge clk);
        branch_taken  = 0;

        @(posedge clk); #1;
        check_pc(32'h0000_0104, "3b. Resume increment from branch");

        @(posedge clk); #1;
        check_pc(32'h0000_0108, "3c. Continue sequential fetch");

        // -------------------------------------------------------------
        // Test 4: Stall hold (hold PC across multiple cycles)
        // -------------------------------------------------------------
        @(negedge clk);
        stall = 1;

        @(posedge clk); #1;
        check_pc(32'h0000_0108, "4a. Stall cycle 1 (PC held)");

        @(posedge clk); #1;
        check_pc(32'h0000_0108, "4b. Stall cycle 2 (PC held)");

        @(posedge clk); #1;
        check_pc(32'h0000_0108, "4c. Stall cycle 3 (PC held)");

        // Release stall
        @(negedge clk);
        stall = 0;

        @(posedge clk); #1;
        check_pc(32'h0000_010C, "4d. Resume sequential after stall");

        // -------------------------------------------------------------
        // Test 5: Stall + Branch priority (stall wins!)
        // -------------------------------------------------------------
        @(negedge clk);
        stall         = 1;
        branch_taken  = 1;
        branch_target = 32'h0000_0500;

        @(posedge clk); #1;
        check_pc(32'h0000_010C, "5a. Stall + Branch (stall wins, PC held)");

        @(posedge clk); #1;
        check_pc(32'h0000_010C, "5b. Stall + Branch cycle 2 (stall wins)");

        // -------------------------------------------------------------
        // Test 6: Release stall while branch still taken
        // -------------------------------------------------------------
        @(negedge clk);
        stall = 0; // Release stall, branch_taken is still 1

        @(posedge clk); #1;
        check_pc(32'h0000_0500, "6a. Branch takes effect after stall released");

        @(negedge clk);
        branch_taken = 0;

        @(posedge clk); #1;
        check_pc(32'h0000_0504, "6b. Sequential after delayed branch");

        // -------------------------------------------------------------
        // Test 7: Mid-operation reset check
        // -------------------------------------------------------------
        @(negedge clk);
        rst_n = 0;

        @(posedge clk); #1;
        check_pc(32'h0000_0000, "7. Asynchronous reset mid-operation");

        #20;
        $display("----------------------------------------------------------------");
        $display("Test Summary: %0d PASSED, %0d FAILED", tests_passed, tests_failed);
        if (tests_failed == 0) begin
            $display(">>> ALL PC UNIT TESTS COMPLETED SUCCESSFULLY! <<<");
        end else begin
            $display(">>> SOME PC UNIT TESTS FAILED! <<<");
        end
        $display("================================================================");
        $finish;
    end

endmodule
