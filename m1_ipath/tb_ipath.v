// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M1 - Instruction Path
// File: tb_ipath.v (Waveform Deliverable Testbench: Sequential Fetch + Branch)
// =============================================================================
// Deliverable Specification (Section 5, Task 4):
//   - Sequential fetch of at least 10 instructions
//   - Demonstrate stall hold capability
//   - Execute one branch redirect and verify sequential fetch resumes
//   - Verify zero 'X' values
//   - Dump VCD waveform to waves/ipath_fetch.vcd
// =============================================================================

`timescale 1ns / 1ps

module tb_ipath;

    // Testbench signals
    reg         clk;
    reg         rst_n;
    reg         stall;
    reg         branch_taken;
    reg  [31:0] branch_target;

    wire [31:0] pc;
    wire [31:0] instr;
    wire        imem_ready;

    integer step_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate integrated instruction path
    ipath #(
        .MEM_FILE("prog_test.hex"),
        .DEPTH(1024)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .pc(pc),
        .instr(instr),
        .imem_ready(imem_ready)
    );

    // 100 MHz clock generation (Period = 10ns)
    always #5 clk = ~clk;

    // Monitor task to verify validity and log execution
    task check_step(input [31:0] exp_pc, input [31:0] exp_instr, input [8*35:1] desc);
        begin
            #1; // Sample after signal settles
            step_count = step_count + 1;
            if (pc === exp_pc && instr === exp_instr && imem_ready === 1'b1) begin
                $display("[PASS] Step %2d (%s) | Time: %4t ns | PC: 0x%08h | Instr: 0x%08h | Ready: %b",
                         step_count, desc, $time, pc, instr, imem_ready);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Step %2d (%s) | Time: %4t ns | Exp PC: 0x%08h (Got 0x%08h) | Exp Instr: 0x%08h (Got 0x%08h)",
                         step_count, desc, $time, exp_pc, pc, exp_instr, instr);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Waveform output
        $dumpfile("waves/ipath_fetch.vcd");
        $dumpvars(0, tb_ipath);

        $display("================================================================================");
        $display("   Project 9 - M1 Deliverable: Instruction Path Fetch & Branch Verification     ");
        $display("================================================================================");

        // Initialize signals
        clk           = 0;
        rst_n         = 0;
        stall         = 0;
        branch_taken  = 0;
        branch_target = 32'h0000_0000;

        // Reset phase: hold in reset across clock edge
        #12;
        rst_n = 1; // Release reset (PC is 0x0000_0000)

        $display("\n--- PHASE 1: SEQUENTIAL FETCH OF 10 INSTRUCTIONS (0x0000_0000 - 0x0000_0024) ---");
        // Sample initial fetched instruction at 0x0000_0000 before rising edge
        check_step(32'h0000_0000, 32'h0050_0093, "Fetch #1 : addi x1, x0, 5");

        // Next 9 sequential instructions clocked on posedge
        @(posedge clk); check_step(32'h0000_0004, 32'h00a0_0113, "Fetch #2 : addi x2, x0, 10");
        @(posedge clk); check_step(32'h0000_0008, 32'h0020_81b3, "Fetch #3 : add x3, x1, x2");
        @(posedge clk); check_step(32'h0000_000c, 32'h4011_8233, "Fetch #4 : sub x4, x3, x1");
        @(posedge clk); check_step(32'h0000_0010, 32'h0020_f2b3, "Fetch #5 : and x5, x1, x2");
        @(posedge clk); check_step(32'h0000_0014, 32'h0020_e333, "Fetch #6 : or x6, x1, x2");
        @(posedge clk); check_step(32'h0000_0018, 32'h0000_2383, "Fetch #7 : lw x7, 0(x0)");
        @(posedge clk); check_step(32'h0000_001c, 32'h0070_2023, "Fetch #8 : sw x7, 0(x0)");
        @(posedge clk); check_step(32'h0000_0020, 32'h0020_8463, "Fetch #9 : beq x1, x2");
        @(posedge clk); check_step(32'h0000_0024, 32'h0020_9463, "Fetch #10: bne x1, x2");

        // Fetch #11 before stall
        @(posedge clk); check_step(32'h0000_0028, 32'h00c0_00ef, "Fetch #11: jal x1 (Pre-stall)");

        $display("\n--- PHASE 2: PIPELINE STALL INJECTION ---");
        // Assert stall: holds PC and instruction
        @(negedge clk);
        stall = 1;
        @(posedge clk); check_step(32'h0000_0028, 32'h00c0_00ef, "Fetch #11: jal x1 (Stall C1)");
        @(posedge clk); check_step(32'h0000_0028, 32'h00c0_00ef, "Fetch #11: jal x1 (Stall C2)");

        // Release stall
        @(negedge clk);
        stall = 0;

        $display("\n--- PHASE 3: BRANCH REDIRECTION (Redirect to 0x0000_0030) ---");
        // Branch redirect to 0x0000_0030 (target instruction: addi x1, x0, 1)
        @(negedge clk);
        branch_taken  = 1;
        branch_target = 32'h0000_0030;

        @(posedge clk);
        check_step(32'h0000_0030, 32'h0010_0093, "Branch Redirect -> 0x30: addi x1, 1");

        // Deassert branch_taken to allow sequential fetch to resume
        @(negedge clk);
        branch_taken = 0;

        $display("\n--- PHASE 4: RESUME SEQUENTIAL FETCH FROM BRANCH TARGET ---");
        @(posedge clk); check_step(32'h0000_0034, 32'h0020_0113, "Fetch #13: addi x2, x0, 2");
        @(posedge clk); check_step(32'h0000_0038, 32'h0030_0193, "Fetch #14: addi x3, x0, 3");
        @(posedge clk); check_step(32'h0000_003c, 32'h0000_006f, "Fetch #15: HALT / jal x0, 0");

        #20;
        $display("\n================================================================================");
        $display("Deliverable Execution Summary: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0) begin
            $display(">>> ALL DELIVERABLE CHECKS PASSED WITH ZERO ERRORS AND ZERO 'X' VALUES! <<<");
            $display("Waveform file successfully written to: waves/ipath_fetch.vcd");
        end else begin
            $display(">>> SOME CHECKS FAILED! <<<");
        end
        $display("================================================================================");
        $finish;
    end

endmodule
