// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M2 - Data Path
// File: tb_dmem.v (Data Memory Core Unit Testbench)
// =============================================================================

`timescale 1ns / 1ps

module tb_dmem;

    reg         clk;
    reg  [9:0]  addr;
    reg  [31:0] wdata;
    reg         we;
    reg  [3:0]  be;
    wire [31:0] rdata;

    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate Unit Under Test (UUT)
    dmem #(
        .INIT_FILE (""),
        .DEPTH     (1024)
    ) uut (
        .clk   (clk),
        .addr  (addr),
        .wdata (wdata),
        .we    (we),
        .be    (be),
        .rdata (rdata)
    );

    // Clock generator: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // Helper task to check read data
    task check_rdata(
        input [31:0] exp_rdata,
        input [127:0] test_name
    );
        begin
            #1; // Short delay for combinational settling
            if (rdata === exp_rdata) begin
                $display("[PASS] %s | Addr: %0d | Got: 0x%08h", test_name, addr, rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s | Addr: %0d | Expected: 0x%08h | Got: 0x%08h",
                         test_name, addr, exp_rdata, rdata);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("waves/tb_dmem.vcd");
        $dumpvars(0, tb_dmem);

        clk   = 0;
        addr  = 10'd0;
        wdata = 32'h0000_0000;
        we    = 0;
        be    = 4'b0000;

        $display("================================================================================");
        $display(" Starting Data Memory Core Unit Tests (tb_dmem.v)");
        $display("================================================================================");

        // 1. Initial State Check (Pre-initialized to 0x0000_0000)
        #10;
        addr = 10'd0;
        check_rdata(32'h0000_0000, "Initial Word 0");
        addr = 10'd512;
        check_rdata(32'h0000_0000, "Initial Word 512");
        addr = 10'd1023;
        check_rdata(32'h0000_0000, "Initial Word 1023");

        // 2. Full Word Synchronous Write (be = 4'b1111)
        @(posedge clk);
        addr  = 10'd4;
        wdata = 32'hCAFEBABE;
        we    = 1;
        be    = 4'b1111;
        @(posedge clk); // Write takes effect here
        we    = 0;
        check_rdata(32'hCAFEBABE, "Word Write 0xCAFEBABE to Word 4");

        // 3. Write Enable Gating (we = 0 should prevent modification)
        @(posedge clk);
        addr  = 10'd4;
        wdata = 32'hFFFFFFFF;
        we    = 0;
        be    = 4'b1111;
        @(posedge clk);
        check_rdata(32'hCAFEBABE, "Write Enable Gating (unmodified)");

        // 4. Byte-Enable Mask Writes on Word 10 (incremental byte assembly)
        // Reset word 10 to 0
        @(posedge clk);
        addr  = 10'd10;
        wdata = 32'h0000_0000;
        we    = 1;
        be    = 4'b1111;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_0000, "Word 10 Cleared");

        // Write Byte 0 (be = 4'b0001)
        @(posedge clk);
        wdata = 32'h0000_00AA;
        we    = 1;
        be    = 4'b0001;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_00AA, "Write Byte 0 (0xAA)");

        // Write Byte 1 (be = 4'b0010)
        @(posedge clk);
        wdata = 32'h0000_BB00;
        we    = 1;
        be    = 4'b0010;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_BBAA, "Write Byte 1 (0xBB)");

        // Write Byte 2 (be = 4'b0100)
        @(posedge clk);
        wdata = 32'h00CC_0000;
        we    = 1;
        be    = 4'b0100;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h00CC_BBAA, "Write Byte 2 (0xCC)");

        // Write Byte 3 (be = 4'b1000)
        @(posedge clk);
        wdata = 32'hDD00_0000;
        we    = 1;
        be    = 4'b1000;
        @(posedge clk);
        we    = 0;
        check_rdata(32'hDDCC_BBAA, "Write Byte 3 (0xDD)");

        // 5. Read-Modify-Write: Overwrite only Byte 1 with 0x99
        @(posedge clk);
        wdata = 32'h0000_9900;
        we    = 1;
        be    = 4'b0010;
        @(posedge clk);
        we    = 0;
        check_rdata(32'hDDCC_99AA, "RMW Overwrite Byte 1 with 0x99");

        // 6. Halfword Writes on Word 20
        @(posedge clk);
        addr  = 10'd20;
        wdata = 32'h0000_1234;
        we    = 1;
        be    = 4'b0011; // Lower halfword
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_1234, "Write Lower Halfword 0x1234");

        @(posedge clk);
        wdata = 32'h5678_0000;
        we    = 1;
        be    = 4'b1100; // Upper halfword
        @(posedge clk);
        we    = 0;
        check_rdata(32'h5678_1234, "Write Upper Halfword 0x5678");

        // 7. Memory Boundary Writes (Word 0 and Word 1023)
        @(posedge clk);
        addr  = 10'd0;
        wdata = 32'h11223344;
        we    = 1;
        be    = 4'b1111;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h11223344, "Write Word 0 (Base)");

        @(posedge clk);
        addr  = 10'd1023;
        wdata = 32'hAABBCCDD;
        we    = 1;
        be    = 4'b1111;
        @(posedge clk);
        we    = 0;
        check_rdata(32'hAABBCCDD, "Write Word 1023 (Top)");

        $display("================================================================================");
        $display(" tb_dmem Test Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("================================================================================");

        if (fail_count > 0) begin
            $display("TEST FAILED!");
            $finish(1);
        end else begin
            $display("TEST PASSED: Data Memory Core verified successfully.");
            $finish(0);
        end
    end

endmodule
