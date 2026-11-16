// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M3 - Shared-Memory (Von Neumann) Comparison Design
// File: tb_arbiter.v (Unit testbench for mem_arbiter - purely combinational)
// =============================================================================
// The testbench plays BOTH the CPU (drives both ports) and the memory (drives
// mem_rdata / mem_hit), so the arbiter is verified in complete isolation.
//   1. Idle                         6. Fetch + store same cycle (store reaches port)
//   2. Fetch only                   7. Byte enables / wdata pass-through
//   3. Load only                    8. Unmapped fetch -> NOP, unmapped load -> 0
//   4. Store only                   9. Load + store together (write wins, old data)
//   5. Fetch + load same cycle     10. No X / Z on any output
// =============================================================================

`timescale 1ns / 1ps

module tb_arbiter;

    // CPU side
    reg  [31:0] imem_addr;
    reg         imem_req;
    wire [31:0] imem_rdata;
    wire        imem_ready;
    reg  [31:0] dmem_addr;
    reg  [31:0] dmem_wdata;
    reg         dmem_re;
    reg         dmem_we;
    reg  [3:0]  dmem_be;
    wire [31:0] dmem_rdata;
    wire        dmem_ready;
    // Memory side
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_be;
    wire        mem_we;
    reg  [31:0] mem_rdata;
    reg         mem_hit;
    // Status
    wire        grant_data;
    wire        conflict;

    integer tests_passed = 0;
    integer tests_failed = 0;

    mem_arbiter uut (
        .imem_addr(imem_addr), .imem_req(imem_req),
        .imem_rdata(imem_rdata), .imem_ready(imem_ready),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_re(dmem_re), .dmem_we(dmem_we), .dmem_be(dmem_be),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_be(mem_be),
        .mem_we(mem_we), .mem_rdata(mem_rdata), .mem_hit(mem_hit),
        .grant_data(grant_data), .conflict(conflict)
    );

    task check(input [31:0] got, input [31:0] exp, input [8*48:1] name);
        begin
            if (got === exp) begin
                $display("[PASS] %0s | expected 0x%08h | got 0x%08h", name, exp, got);
                tests_passed = tests_passed + 1;
            end else begin
                $display("[FAIL] %0s | expected 0x%08h | got 0x%08h", name, exp, got);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    task no_x_check(input [8*48:1] name);
        begin
            if (^{imem_rdata, imem_ready, dmem_rdata, dmem_ready, mem_addr,
                  mem_wdata, mem_be, mem_we, grant_data, conflict} === 1'bx) begin
                $display("[FAIL] %0s | X/Z detected on an output", name);
                tests_failed = tests_failed + 1;
            end else begin
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    task cpu(input ireq, input [31:0] iaddr, input re, input we,
             input [31:0] daddr, input [31:0] wdata, input [3:0] be);
        begin
            imem_req = ireq; imem_addr = iaddr;
            dmem_re = re; dmem_we = we; dmem_addr = daddr;
            dmem_wdata = wdata; dmem_be = be;
            #1;
        end
    endtask

    initial begin
        $dumpfile("waves/tb_arbiter.vcd");
        $dumpvars(0, tb_arbiter);

        mem_rdata = 32'hCAFE_0001;
        mem_hit   = 1'b1;

        $display("================================================================");
        $display(" M3 mem_arbiter unit tests");
        $display("================================================================");

        // 1. Idle
        cpu(0, 32'h0, 0, 0, 32'h0, 32'h0, 4'b0000);
        check(imem_ready, 1, "T1 idle: imem_ready = 1");
        check(dmem_ready, 1, "T1 idle: dmem_ready = 1");
        check(conflict,   0, "T1 idle: no conflict");
        check(mem_we,     0, "T1 idle: no write");
        no_x_check("T1 idle: no X");

        // 2. Fetch only
        cpu(1, 32'h0000_0010, 0, 0, 32'h1000_0000, 32'h0, 4'b1111);
        mem_rdata = 32'h00d5_85b3; #1;
        check(mem_addr,   32'h0000_0010, "T2 fetch only: port = imem_addr");
        check(imem_ready, 1,             "T2 fetch only: imem_ready = 1");
        check(imem_rdata, 32'h00d5_85b3, "T2 fetch only: imem_rdata = mem");
        check(grant_data, 0,             "T2 fetch only: port not given to data");
        check(conflict,   0,             "T2 fetch only: no conflict");

        // 3. Load only
        cpu(0, 32'h0000_0010, 1, 0, 32'h1000_0008, 32'h0, 4'b1111);
        mem_rdata = 32'h0000_001E; #1;
        check(mem_addr,   32'h1000_0008, "T3 load only: port = dmem_addr");
        check(dmem_ready, 1,             "T3 load only: dmem_ready = 1");
        check(dmem_rdata, 32'h0000_001E, "T3 load only: dmem_rdata = mem");
        check(conflict,   0,             "T3 load only: no conflict (no fetch)");

        // 4. Store only
        cpu(0, 32'h0, 0, 1, 32'h1000_0040, 32'h0000_0550, 4'b1111);
        check(mem_we,     1,             "T4 store only: mem_we = 1");
        check(mem_addr,   32'h1000_0040, "T4 store only: port = dmem_addr");
        check(mem_wdata,  32'h0000_0550, "T4 store only: wdata passed");

        // 5. Fetch + load same cycle -> data wins
        cpu(1, 32'h0000_0014, 1, 0, 32'h1000_0004, 32'h0, 4'b1111);
        mem_rdata = 32'h0000_0014; #1;
        check(mem_addr,   32'h1000_0004, "T5 fetch+load: port = dmem_addr");
        check(dmem_ready, 1,             "T5 fetch+load: dmem_ready = 1");
        check(imem_ready, 0,             "T5 fetch+load: imem_ready = 0 (stall)");
        check(dmem_rdata, 32'h0000_0014, "T5 fetch+load: load data correct");
        check(imem_rdata, 32'h0000_0013, "T5 fetch+load: imem_rdata = NOP");
        check(conflict,   1,             "T5 fetch+load: conflict = 1");

        // 6. Fetch + store same cycle -> data wins, store goes through
        cpu(1, 32'h0000_0014, 0, 1, 32'h1000_0040, 32'h1234_5678, 4'b1111);
        check(imem_ready, 0,             "T6 fetch+store: imem_ready = 0");
        check(mem_we,     1,             "T6 fetch+store: mem_we = 1");
        check(mem_addr,   32'h1000_0040, "T6 fetch+store: port = dmem_addr");
        check(conflict,   1,             "T6 fetch+store: conflict = 1");

        // 7. Byte enables pass-through
        cpu(0, 32'h0, 0, 1, 32'h1000_0000, 32'hAABB_CCDD, 4'b0100);
        check(mem_be,     4'b0100,       "T7 byte enable passed through");
        check(mem_wdata,  32'hAABB_CCDD, "T7 wdata passed through");

        // 8. Unmapped addresses
        mem_hit = 1'b0; mem_rdata = 32'h0000_0000;
        cpu(1, 32'h2000_0000, 0, 0, 32'h0, 32'h0, 4'b1111);
        check(imem_rdata, 32'h0000_0013, "T8 unmapped fetch -> NOP");
        cpu(0, 32'h0, 1, 0, 32'h1000_1000, 32'h0, 4'b1111);
        check(dmem_rdata, 32'h0000_0000, "T8 unmapped load -> 0");
        mem_hit = 1'b1;

        // 9. Load + store at the same time: write wins, read shows old data
        mem_rdata = 32'h0000_00AA;  // old contents
        cpu(0, 32'h0, 1, 1, 32'h1000_0000, 32'h0000_00BB, 4'b1111);
        check(mem_we,     1,             "T9 re+we: write performed");
        check(dmem_rdata, 32'h0000_00AA, "T9 re+we: read returns old data");

        // 10. Back to idle, X check
        cpu(0, 32'h0, 0, 0, 32'h0, 32'h0, 4'b0000);
        no_x_check("T10 final: no X");

        $display("================================================================");
        $display(" tb_arbiter: %0d passed, %0d failed", tests_passed, tests_failed);
        $display("================================================================");
        if (tests_failed != 0) $fatal(1, "tb_arbiter FAILED");
        $finish;
    end

endmodule
