`timescale 1ns / 1ps

// Testbench for data memory controller
module tb_dmem_ctrl;

    reg         clk;
    reg         rst_n;

    reg  [31:0] dmem_addr;
    reg  [31:0] dmem_wdata;
    reg         dmem_re;
    reg         dmem_we;
    reg  [3:0]  dmem_be;
    wire [31:0] dmem_rdata;
    wire        dmem_ready;

    wire        access_fault;

    integer pass_count = 0;
    integer fail_count = 0;

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

    always #5 clk = ~clk;

    // helper to do a write
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

    // helper to do a read and check data
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
            #1;
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

        clk        = 0;
        rst_n      = 0;
        dmem_addr  = 32'h0000_0000;
        dmem_wdata = 32'h0000_0000;
        dmem_re    = 1'b0;
        dmem_we    = 1'b0;
        dmem_be    = 4'b0000;

        $display("Testing data memory controller...");

        // reset
        #20;
        rst_n = 1;
        #10;

        if (dmem_ready === 1'b1 && access_fault === 1'b0) begin
            $display("[PASS] Init: dmem_ready=1 and access_fault=0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Init check failed");
            fail_count = fail_count + 1;
        end

        // 1. write a word and read it back
        write_mem(32'h1000_0010, 32'hDEADBEEF, 4'b1111);
        read_and_check(32'h1000_0010, 32'hDEADBEEF, "Test 1: Word Read");

        // 2. test byte enables (single bytes and halfwords)
        write_mem(32'h1000_0020, 32'h0000_0000, 4'b1111);
        write_mem(32'h1000_0020, 32'h0000_0011, 4'b0001);
        read_and_check(32'h1000_0020, 32'h0000_0011, "Byte 0 Write (0x11)");

        write_mem(32'h1000_0020, 32'h0000_2200, 4'b0010);
        read_and_check(32'h1000_0020, 32'h0000_2211, "Byte 1 Write (0x22)");

        write_mem(32'h1000_0020, 32'h0033_0000, 4'b0100);
        read_and_check(32'h1000_0020, 32'h0033_2211, "Byte 2 Write (0x33)");

        write_mem(32'h1000_0020, 32'h4400_0000, 4'b1000);
        read_and_check(32'h1000_0020, 32'h4433_2211, "Byte 3 Write (0x44)");

        write_mem(32'h1000_0024, 32'h0000_AAAA, 4'b0011);
        read_and_check(32'h1000_0024, 32'h0000_AAAA, "Lower Halfword (0xAAAA)");

        write_mem(32'h1000_0024, 32'hBBBB_0000, 4'b1100);
        read_and_check(32'h1000_0024, 32'hBBBB_AAAA, "Upper Halfword (0xBBBB)");

        // 3. read right after write at the same address
        @(posedge clk);
        dmem_addr  <= 32'h1000_0050;
        dmem_wdata <= 32'h9876_5432;
        dmem_we    <= 1'b1;
        dmem_re    <= 1'b0;
        dmem_be    <= 4'b1111;

        @(posedge clk);
        dmem_we    <= 1'b0;
        dmem_re    <= 1'b1;
        #1;
        if (dmem_rdata === 32'h9876_5432) begin
            $display("[PASS] RAW Same Address: read got 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] RAW Same Address failed");
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_re <= 1'b0;

        // 4. back-to-back writes and reads
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
            $display("[FAIL] Back-to-back Read 1 failed");
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_addr <= 32'h1000_0064; dmem_we <= 1'b0; dmem_re <= 1'b1;
        #1;
        if (dmem_rdata === 32'h2222_2222) begin
            $display("[PASS] Back-to-back Read 2: Addr 0x1000_0064 = 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Back-to-back Read 2 failed");
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_re <= 1'b0;

        // 5. boundary addresses (0x1000_0000 and 0x1000_0FFC)
        write_mem(32'h1000_0000, 32'hFEED_FACE, 4'b1111);
        read_and_check(32'h1000_0000, 32'hFEED_FACE, "Boundary Base 0x1000_0000");

        write_mem(32'h1000_0FFC, 32'h0BAD_F00D, 4'b1111);
        read_and_check(32'h1000_0FFC, 32'h0BAD_F00D, "Boundary Top Word 0x1000_0FFC");

        // 6. out of range access should return 0 and set access_fault
        if (access_fault === 1'b0) begin
            $display("[PASS] Fault initially 0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Fault not 0");
            fail_count = fail_count + 1;
        end

        // read from invalid address 0x1000_1000
        @(posedge clk);
        dmem_addr <= 32'h1000_1000;
        dmem_re   <= 1'b1;
        dmem_we   <= 1'b0;
        #1;
        if (dmem_rdata === 32'h0000_0000) begin
            $display("[PASS] Out-of-range Read: returned 0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Out-of-range Read failed");
            fail_count = fail_count + 1;
        end

        @(posedge clk);
        dmem_re <= 1'b0;
        #1;
        if (access_fault === 1'b1) begin
            $display("[PASS] Sticky Fault: access_fault asserted");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Sticky Fault not set");
            fail_count = fail_count + 1;
        end

        // try writing to invalid address
        @(posedge clk);
        dmem_addr  <= 32'h2000_0000;
        dmem_wdata <= 32'hDEAD_BEEF;
        dmem_we    <= 1'b1;
        dmem_be    <= 4'b1111;
        @(posedge clk);
        dmem_we    <= 1'b0;

        // make sure fault stays sticky on valid read
        read_and_check(32'h1000_0000, 32'hFEED_FACE, "Valid Read after Fault");
        if (access_fault === 1'b1) begin
            $display("[PASS] Sticky Fault stayed high");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Sticky Fault dropped");
            fail_count = fail_count + 1;
        end

        // reset should clear fault
        @(posedge clk);
        rst_n = 0;
        #15;
        if (access_fault === 1'b0) begin
            $display("[PASS] Reset cleared fault");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Reset did not clear fault");
            fail_count = fail_count + 1;
        end
        rst_n = 1;
        #10;

        // 7. simultaneous read and write (write wins, read returns old data)
        write_mem(32'h1000_0080, 32'h01D0_0001, 4'b1111);

        @(posedge clk);
        dmem_addr  <= 32'h1000_0080;
        dmem_wdata <= 32'h0E00_0002;
        dmem_re    <= 1'b1;
        dmem_we    <= 1'b1;
        dmem_be    <= 4'b1111;
        #1;
        if (dmem_rdata === 32'h01D0_0001) begin
            $display("[PASS] Simultaneous re/we: read got old data 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Simultaneous re/we read failed");
            fail_count = fail_count + 1;
        end

        @(posedge clk);
        dmem_we <= 1'b0;
        dmem_re <= 1'b1;
        #1;
        if (dmem_rdata === 32'h0E00_0002) begin
            $display("[PASS] Simultaneous re/we: write updated data to 0x%08h", dmem_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Simultaneous re/we write failed");
            fail_count = fail_count + 1;
        end
        @(posedge clk);
        dmem_re <= 1'b0;

        #20;
        $display("tb_dmem_ctrl results: %0d passed, %0d failed", pass_count, fail_count);

        if (fail_count > 0) begin
            $finish(1);
        end else begin
            $finish(0);
        end
    end

endmodule
