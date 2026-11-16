`timescale 1ns / 1ps

// Testbench for data memory core
module tb_dmem;

    reg         clk;
    reg  [9:0]  addr;
    reg  [31:0] wdata;
    reg         we;
    reg  [3:0]  be;
    wire [31:0] rdata;

    integer pass_count = 0;
    integer fail_count = 0;

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

    always #5 clk = ~clk;

    // helper to check read data
    task check_rdata(
        input [31:0] exp_rdata,
        input [127:0] test_name
    );
        begin
            #1;
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

        $display("Testing data memory core...");

        // check that memory starts at 0
        #10;
        addr = 10'd0;
        check_rdata(32'h0000_0000, "Initial Word 0");
        addr = 10'd512;
        check_rdata(32'h0000_0000, "Initial Word 512");
        addr = 10'd1023;
        check_rdata(32'h0000_0000, "Initial Word 1023");

        // test full word write
        @(posedge clk);
        addr  = 10'd4;
        wdata = 32'hCAFEBABE;
        we    = 1;
        be    = 4'b1111;
        @(posedge clk);
        we    = 0;
        check_rdata(32'hCAFEBABE, "Word Write 0xCAFEBABE to Word 4");

        // make sure we=0 does not write anything
        @(posedge clk);
        addr  = 10'd4;
        wdata = 32'hFFFFFFFF;
        we    = 0;
        be    = 4'b1111;
        @(posedge clk);
        check_rdata(32'hCAFEBABE, "Write Enable Gating (unmodified)");

        // test writing one byte at a time into word 10
        @(posedge clk);
        addr  = 10'd10;
        wdata = 32'h0000_0000;
        we    = 1;
        be    = 4'b1111;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_0000, "Word 10 Cleared");

        @(posedge clk);
        wdata = 32'h0000_00AA;
        we    = 1;
        be    = 4'b0001;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_00AA, "Write Byte 0 (0xAA)");

        @(posedge clk);
        wdata = 32'h0000_BB00;
        we    = 1;
        be    = 4'b0010;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_BBAA, "Write Byte 1 (0xBB)");

        @(posedge clk);
        wdata = 32'h00CC_0000;
        we    = 1;
        be    = 4'b0100;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h00CC_BBAA, "Write Byte 2 (0xCC)");

        @(posedge clk);
        wdata = 32'hDD00_0000;
        we    = 1;
        be    = 4'b1000;
        @(posedge clk);
        we    = 0;
        check_rdata(32'hDDCC_BBAA, "Write Byte 3 (0xDD)");

        // test overwriting just one byte (byte 1)
        @(posedge clk);
        wdata = 32'h0000_9900;
        we    = 1;
        be    = 4'b0010;
        @(posedge clk);
        we    = 0;
        check_rdata(32'hDDCC_99AA, "RMW Overwrite Byte 1 with 0x99");

        // test halfword writes
        @(posedge clk);
        addr  = 10'd20;
        wdata = 32'h0000_1234;
        we    = 1;
        be    = 4'b0011;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h0000_1234, "Write Lower Halfword 0x1234");

        @(posedge clk);
        wdata = 32'h5678_0000;
        we    = 1;
        be    = 4'b1100;
        @(posedge clk);
        we    = 0;
        check_rdata(32'h5678_1234, "Write Upper Halfword 0x5678");

        // test boundary words at index 0 and 1023
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

        $display("tb_dmem results: %0d passed, %0d failed", pass_count, fail_count);

        if (fail_count > 0) begin
            $finish(1);
        end else begin
            $finish(0);
        end
    end

endmodule
