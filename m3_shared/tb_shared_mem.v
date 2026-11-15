// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M3 - Shared-Memory (Von Neumann) Comparison Design
// File: tb_shared_mem.v (System-level testbench for shared_mem)
// =============================================================================
// The testbench plays the CPU and drives BOTH ports with scripted request
// patterns (no CPU, no M1/M2 code needed). Required tests (Section 5 / M3):
//   T1  Reset values (conflict_count = 0, access_fault = 0)
//   T2  Unchanged .hex files: every program + data word reads back correctly
//   T3  Fetch only               T4  Data only (load + store)
//   T5  Fetch + load same cycle  T6  Fetch + store same cycle
//   T7  Byte-enable writes (byte and halfword)
//   T8  Long run of consecutive loads: fetch starves, then is served
//   T9  Store burst during fetch stall: no store lost or duplicated
//   T10 Reset during stall
//   T11 Unmapped addresses + sticky access_fault
//   T12 Boundary addresses   T13 Simultaneous re + we (write wins, old data)
//   T14 Von Neumann property: data port can read the program region
//   T15 Random CPU-like trace: conflict_count == number of overlap cycles
//   +   No X/Z on any output in any cycle out of reset
// Outputs: waves/tb_shared_mem.vcd, waves/conflict_log.txt (cycle-by-cycle log)
// =============================================================================

`timescale 1ns / 1ps

module tb_shared_mem;

    parameter PROG_FILE = "hex/m3_prog.hex";
    parameter DATA_FILE = "hex/m3_prog_data.hex";

    localparam [31:0] NOP   = 32'h0000_0013;
    localparam [31:0] DBASE = 32'h1000_0000;

    // Clock / reset
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n;

    // CPU ports
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
    wire [31:0] conflict_count;
    wire        access_fault;

    shared_mem #(
        .PROG_FILE(PROG_FILE),
        .DATA_FILE(DATA_FILE)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_req(imem_req),
        .imem_rdata(imem_rdata), .imem_ready(imem_ready),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_re(dmem_re), .dmem_we(dmem_we), .dmem_be(dmem_be),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready),
        .conflict_count(conflict_count), .access_fault(access_fault)
    );

    // Reference copies of the hex files (loaded independently of the DUT)
    reg [31:0] ref_prog [0:1023];
    reg [31:0] ref_data [0:1023];

    integer tests_passed = 0;
    integer tests_failed = 0;
    integer writes_seen  = 0;   // real array writes observed at clock edges
    integer x_errors     = 0;
    integer cycle        = 0;
    integer log_fd;
    integer i, k, mism, cc0, w0, expected_conf;
    reg     r_ireq, r_re, r_we;

    // ---------------- Monitors ----------------
    // Count every write that actually lands in the array
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (rst_n && dut.mem_we && dut.u_core.hit)
            writes_seen = writes_seen + 1;
    end

    // Mid-cycle log + X/Z check (inputs change at posedge+1, so negedge is stable)
    always @(negedge clk) begin
        $fdisplay(log_fd, "%5d | %b | %b %08h | %b %b %08h | %b %b | %08h %08h | %b | %0d",
                  cycle, rst_n, imem_req, imem_addr, dmem_re, dmem_we, dmem_addr,
                  imem_ready, dmem_ready, imem_rdata, dmem_rdata,
                  dut.conflict, conflict_count);
        if (rst_n && (^{imem_rdata, imem_ready, dmem_rdata, dmem_ready,
                        conflict_count, access_fault} === 1'bx))
            x_errors = x_errors + 1;
    end

    // ---------------- Helpers ----------------
    task check(input [31:0] got, input [31:0] exp, input [8*56:1] name);
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

    // Drive both CPU ports for the current cycle, then let logic settle
    task drive(input ireq, input [31:0] iaddr, input re, input we,
               input [31:0] daddr, input [31:0] wdata, input [3:0] be);
        begin
            imem_req = ireq; imem_addr = iaddr;
            dmem_re = re; dmem_we = we; dmem_addr = daddr;
            dmem_wdata = wdata; dmem_be = be;
            #1;
        end
    endtask

    task idle;
        begin
            drive(0, 32'h0, 0, 0, 32'h0, 32'h0, 4'b1111);
        end
    endtask

    // Advance one clock edge; inputs may change 1 ns after the edge
    task tick;
        begin
            @(posedge clk); #1;
        end
    endtask

    // Single-cycle load used for read-back checks (fetch idle)
    task load_check(input [31:0] addr, input [31:0] exp, input [8*56:1] name);
        begin
            drive(0, 32'h0, 1, 0, addr, 32'h0, 4'b1111);
            check(dmem_rdata, exp, name);
            tick;
        end
    endtask

    // ---------------- Test sequence ----------------
    initial begin
        $dumpfile("waves/tb_shared_mem.vcd");
        $dumpvars(0, tb_shared_mem);
        log_fd = $fopen("waves/conflict_log.txt", "w");
        $fdisplay(log_fd, "M3 shared_mem cycle log (sampled mid-cycle)");
        $fdisplay(log_fd, "cycle | rst_n | ireq imem_addr | re we dmem_addr | iready dready | imem_rdata dmem_rdata | conflict | conflict_count");

        for (i = 0; i < 1024; i = i + 1) begin
            ref_prog[i] = NOP;
            ref_data[i] = 32'h0;
        end
        $readmemh(PROG_FILE, ref_prog);
        $readmemh(DATA_FILE, ref_data);

        $display("================================================================");
        $display(" M3 shared_mem system tests  (PROG_FILE=%0s)", PROG_FILE);
        $display("================================================================");

        // ---------------- T1 reset ----------------
        rst_n = 1'b0;
        idle;
        tick; tick;
        rst_n = 1'b1;
        check(conflict_count, 0, "T1 reset: conflict_count = 0");
        check(access_fault,   0, "T1 reset: access_fault = 0");

        // ---------------- T2 unchanged hex files ----------------
        mism = 0;
        for (i = 0; i < 1024; i = i + 1) begin
            drive(1, i * 4, 0, 0, 32'h0, 32'h0, 4'b1111);
            if (imem_rdata !== ref_prog[i] || imem_ready !== 1'b1) mism = mism + 1;
        end
        check(mism, 0, "T2 all 1024 program words fetched correctly");
        mism = 0;
        for (i = 0; i < 1024; i = i + 1) begin
            drive(0, 32'h0, 1, 0, DBASE + i * 4, 32'h0, 4'b1111);
            if (dmem_rdata !== ref_data[i]) mism = mism + 1;
        end
        check(mism, 0, "T2 all 1024 data words loaded correctly");
        idle; tick;
        check(conflict_count, 0, "T2 scans caused no conflicts");

        // ---------------- T3 fetch only ----------------
        cc0 = conflict_count;
        for (i = 0; i < 4; i = i + 1) begin
            drive(1, i * 4, 0, 0, 32'h0, 32'h0, 4'b1111);
            check(imem_ready, 1,           "T3 fetch only: imem_ready = 1");
            check(imem_rdata, ref_prog[i], "T3 fetch only: correct instruction");
            tick;
        end
        check(conflict_count, cc0, "T3 fetch only: no conflicts counted");

        // ---------------- T4 data only ----------------
        drive(0, 32'h0, 1, 0, DBASE + 8, 32'h0, 4'b1111);
        check(dmem_ready, 1,           "T4 load only: dmem_ready = 1");
        check(dmem_rdata, ref_data[2], "T4 load only: data correct");
        tick;
        drive(0, 32'h0, 0, 1, DBASE + 32'h80, 32'hDEAD_BEEF, 4'b1111);
        check(dmem_ready, 1, "T4 store only: dmem_ready = 1");
        tick;
        load_check(DBASE + 32'h80, 32'hDEAD_BEEF, "T4 store then load: read back");
        check(conflict_count, cc0, "T4 data only: no conflicts counted");

        // ---------------- T5 fetch + load same cycle ----------------
        cc0 = conflict_count;
        drive(1, 32'h14, 1, 0, DBASE + 4, 32'h0, 4'b1111);
        check(imem_ready, 0,           "T5 fetch+load: imem_ready = 0 (stall)");
        check(dmem_ready, 1,           "T5 fetch+load: dmem_ready = 1");
        check(dmem_rdata, ref_data[1], "T5 fetch+load: load served correctly");
        tick;
        check(conflict_count, cc0 + 1, "T5 fetch+load: conflict_count +1");
        drive(1, 32'h14, 0, 0, 32'h0, 32'h0, 4'b1111);   // CPU holds PC
        check(imem_ready, 1,           "T5 next cycle: fetch served");
        check(imem_rdata, ref_prog[5], "T5 next cycle: correct instruction");
        tick;
        check(conflict_count, cc0 + 1, "T5 served fetch not counted again");

        // ---------------- T6 fetch + store same cycle ----------------
        cc0 = conflict_count; w0 = writes_seen;
        drive(1, 32'h18, 0, 1, DBASE + 32'h44, 32'h0BAD_F00D, 4'b1111);
        check(imem_ready, 0, "T6 fetch+store: imem_ready = 0 (stall)");
        check(dmem_ready, 1, "T6 fetch+store: dmem_ready = 1");
        tick;
        check(writes_seen, w0 + 1,     "T6 fetch+store: exactly one write");
        check(conflict_count, cc0 + 1, "T6 fetch+store: conflict_count +1");
        drive(1, 32'h18, 0, 0, 32'h0, 32'h0, 4'b1111);
        check(imem_ready, 1,           "T6 next cycle: fetch served");
        check(imem_rdata, ref_prog[6], "T6 next cycle: correct instruction");
        tick;
        check(writes_seen, w0 + 1,     "T6 store not repeated after stall");
        load_check(DBASE + 32'h44, 32'h0BAD_F00D, "T6 stored value correct");

        // ---------------- T7 byte enables ----------------
        drive(0, 32'h0, 0, 1, DBASE + 32'h44, 32'hAABB_CCDD, 4'b0010); tick;
        load_check(DBASE + 32'h44, 32'h0BAD_CC0D, "T7 byte 1 write only");
        drive(0, 32'h0, 0, 1, DBASE + 32'h44, 32'h1122_0000, 4'b1100); tick;
        load_check(DBASE + 32'h44, 32'h1122_CC0D, "T7 upper halfword write");
        drive(0, 32'h0, 0, 1, DBASE + 32'h44, 32'h0000_00EE, 4'b0001); tick;
        load_check(DBASE + 32'h44, 32'h1122_CCEE, "T7 byte 0 write only");
        drive(0, 32'h0, 0, 1, DBASE + 32'h44, 32'h0099_0000, 4'b0100); tick;
        load_check(DBASE + 32'h44, 32'h1199_CCEE, "T7 byte 2 write only");

        // ---------------- T8 long run of consecutive loads ----------------
        cc0 = conflict_count; mism = 0;
        for (k = 0; k < 8; k = k + 1) begin
            drive(1, 32'h1C, 1, 0, DBASE + k * 4, 32'h0, 4'b1111);
            if (imem_ready !== 1'b0 || dmem_rdata !== ref_data[k]) mism = mism + 1;
            tick;
        end
        check(mism, 0,                 "T8 8 loads served, fetch stalled each cycle");
        check(conflict_count, cc0 + 8, "T8 conflict_count +8");
        drive(1, 32'h1C, 0, 0, 32'h0, 32'h0, 4'b1111);
        check(imem_ready, 1,           "T8 fetch served after last load");
        check(imem_rdata, ref_prog[7], "T8 starved fetch gets correct instruction");
        tick;

        // ---------------- T9 store burst during fetch stall ----------------
        cc0 = conflict_count; w0 = writes_seen;
        for (k = 0; k < 6; k = k + 1) begin
            drive(1, 32'h20, 0, 1, DBASE + 32'h100 + k * 4, 32'h5000_0000 + k, 4'b1111);
            tick;
        end
        check(writes_seen, w0 + 6,     "T9 6 stores -> exactly 6 writes");
        check(conflict_count, cc0 + 6, "T9 conflict_count +6");
        drive(1, 32'h20, 0, 0, 32'h0, 32'h0, 4'b1111);
        check(imem_ready, 1,           "T9 fetch served after store burst");
        check(imem_rdata, ref_prog[8], "T9 correct instruction after burst");
        tick; idle; tick;
        check(writes_seen, w0 + 6,     "T9 no duplicated store afterwards");
        mism = 0;
        for (k = 0; k < 6; k = k + 1) begin
            drive(0, 32'h0, 1, 0, DBASE + 32'h100 + k * 4, 32'h0, 4'b1111);
            if (dmem_rdata !== 32'h5000_0000 + k) mism = mism + 1;
        end
        check(mism, 0, "T9 every stored value present (none lost)");
        load_check(DBASE + 32'h0FC, 32'h0, "T9 word before burst untouched");
        load_check(DBASE + 32'h118, 32'h0, "T9 word after burst untouched");

        // ---------------- T10 reset during stall ----------------
        w0 = writes_seen;
        drive(1, 32'h24, 1, 0, DBASE, 32'h0, 4'b1111);           // stall cycle
        tick;
        drive(1, 32'h24, 0, 1, DBASE + 32'h100, 32'hFFFF_FFFF, 4'b1111);
        check(imem_ready, 0, "T10 fetch stalled when reset arrives");
        rst_n = 1'b0; #1;                                          // async reset
        check(conflict_count, 0, "T10 reset clears conflict_count at once");
        tick;
        check(writes_seen, w0, "T10 store during reset is blocked");
        drive(1, 32'h0, 0, 0, 32'h0, 32'h0, 4'b1111);              // CPU restarts at 0
        rst_n = 1'b1; #1;
        check(imem_ready, 1,           "T10 after reset: fetch served");
        check(imem_rdata, ref_prog[0], "T10 after reset: instruction at 0");
        tick;
        check(conflict_count, 0, "T10 after reset: count still 0");
        load_check(DBASE + 32'h100, 32'h5000_0000, "T10 memory kept across reset");
        load_check(DBASE + 32'h44,  32'h1199_CCEE, "T10 earlier store kept");

        // ---------------- T11 unmapped addresses ----------------
        drive(1, 32'h2000_0000, 0, 0, 32'h0, 32'h0, 4'b1111);
        check(imem_rdata, NOP, "T11 unmapped fetch -> NOP");
        tick;
        check(access_fault, 0, "T11 unmapped fetch does not set access_fault");
        w0 = writes_seen;
        drive(0, 32'h0, 1, 0, DBASE + 32'h1000, 32'h0, 4'b1111);
        check(dmem_rdata, 32'h0, "T11 unmapped load (0x1000_1000) -> 0");
        tick;
        check(access_fault, 1, "T11 access_fault set");
        drive(0, 32'h0, 0, 1, 32'h3000_0000, 32'h1234_5678, 4'b1111);
        tick;
        check(writes_seen, w0, "T11 unmapped store ignored");
        idle; tick;
        check(access_fault, 1, "T11 access_fault is sticky");

        // ---------------- T12 boundary addresses ----------------
        drive(1, 32'h0000_0FFC, 0, 0, 32'h0, 32'h0, 4'b1111);
        check(imem_rdata, ref_prog[1023], "T12 last program word 0x0000_0FFC");
        drive(1, 32'h0000_1000, 0, 0, 32'h0, 32'h0, 4'b1111);
        check(imem_rdata, NOP,            "T12 0x0000_1000 is outside program");
        tick;
        load_check(DBASE, ref_data[0],              "T12 first data word 0x1000_0000");
        drive(0, 32'h0, 0, 1, DBASE + 32'hFFC, 32'hC0DE_0FFC, 4'b1111); tick;
        load_check(DBASE + 32'hFFC, 32'hC0DE_0FFC,  "T12 last data word 0x1000_0FFC");

        // ---------------- T13 simultaneous re + we ----------------
        drive(0, 32'h0, 0, 1, DBASE + 32'h48, 32'h0000_0077, 4'b1111); tick;
        drive(0, 32'h0, 1, 1, DBASE + 32'h48, 32'h0000_0099, 4'b1111);
        check(dmem_rdata, 32'h0000_0077, "T13 re+we: read returns old data");
        tick;
        load_check(DBASE + 32'h48, 32'h0000_0099, "T13 re+we: write took effect");

        // ---------------- T14 Von Neumann property ----------------
        load_check(32'h0000_0000, ref_prog[0], "T14 data port reads program word 0");
        load_check(32'h0000_0024, ref_prog[9], "T14 data port reads program word 9");

        // ---------------- T15 random CPU-like trace ----------------
        cc0 = conflict_count; expected_conf = 0; mism = 0;
        k = 32'd2024;   // seed
        for (i = 0; i < 200; i = i + 1) begin
            r_ireq = $random(k);
            r_re   = $random(k);
            r_we   = !r_re && $random(k);
            drive(r_ireq, (i % 64) * 4, r_re, r_we, DBASE + 32'h200 + (i % 32) * 4,
                  32'hA000_0000 + i, 4'b1111);
            if (r_ireq && (r_re || r_we)) expected_conf = expected_conf + 1;
            if (imem_ready !== !(r_re || r_we)) mism = mism + 1;
            if (dmem_ready !== 1'b1) mism = mism + 1;
            tick;
        end
        check(mism, 0, "T15 handshakes correct on all 200 random cycles");
        check(conflict_count - cc0, expected_conf, "T15 conflict_count = overlap cycles");
        $display("       T15: %0d overlap cycles out of 200 random cycles", expected_conf);

        // ---------------- X check + summary ----------------
        idle; tick;
        check(x_errors, 0, "No X/Z on any output in any cycle");

        $fdisplay(log_fd, "FINAL conflict_count = %0d", conflict_count);
        $fclose(log_fd);

        $display("================================================================");
        $display(" tb_shared_mem: %0d passed, %0d failed", tests_passed, tests_failed);
        $display("================================================================");
        if (tests_failed != 0) $fatal(1, "tb_shared_mem FAILED");
        $finish;
    end

endmodule
