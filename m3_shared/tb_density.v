// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M3 - Shared-Memory (Von Neumann) Comparison Design
// File: tb_density.v (Analysis testbench: stall cycles vs load/store density)
// =============================================================================
// A behavioural 2-stage requester (Fetch | Execute) drives shared_mem the way a
// simple pipelined CPU would: every cycle it fetches the next instruction while
// the previous instruction executes. If the executing instruction is a load or
// store, the data access wins and the fetch is delayed one cycle.
//
// For N instructions with load/store density d (5 settings: 0%,25%,50%,75%,100%)
// the analytical model in the analysis note predicts:
//     conflicts      = number of load/stores that are not the last instruction
//     shared cycles  = N + 1 (pipeline fill) + conflicts
//     Harvard cycles = N + 1 (no structural conflicts)
// The testbench checks the hardware against these formulas and writes
// waves/density_sweep.csv for the report.
// =============================================================================

`timescale 1ns / 1ps

module tb_density;

    localparam integer N     = 100;
    localparam [31:0]  DBASE = 32'h1000_0000;

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n;

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

    shared_mem dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_req(imem_req),
        .imem_rdata(imem_rdata), .imem_ready(imem_ready),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_re(dmem_re), .dmem_we(dmem_we), .dmem_be(dmem_be),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready),
        .conflict_count(conflict_count), .access_fault(access_fault)
    );

    integer tests_passed = 0;
    integer tests_failed = 0;
    integer csv_fd;
    integer k, i, fetch_idx, retired, cycles, n_mem, exp_conf, exp_cycles;
    reg     ex_valid, ex_mem, ex_store;
    reg [31:0] ex_idx;

    // Instruction i is a load/store when (i % 4) < k  -> density k/4.
    // Memory instructions alternate load, store, load, store ...
    function is_mem(input integer idx, input integer kk);
        is_mem = ((idx % 4) < kk);
    endfunction

    task check(input [31:0] got, input [31:0] exp, input [8*56:1] name);
        begin
            if (got === exp) begin
                $display("[PASS] %0s | expected %0d | got %0d", name, exp, got);
                tests_passed = tests_passed + 1;
            end else begin
                $display("[FAIL] %0s | expected %0d | got %0d", name, exp, got);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("waves/tb_density.vcd");
        $dumpvars(0, tb_density);
        csv_fd = $fopen("waves/density_sweep.csv", "w");
        $fdisplay(csv_fd, "density_pct,instructions,load_store,conflicts,shared_cycles,harvard_cycles,shared_cpi,harvard_cpi,slowdown_pct");

        $display("================================================================");
        $display(" M3 density sweep: stall cycles vs load/store density (N=%0d)", N);
        $display("================================================================");

        for (k = 0; k <= 4; k = k + 1) begin
            // Reset between runs
            rst_n = 1'b0;
            imem_req = 0; imem_addr = 0; dmem_re = 0; dmem_we = 0;
            dmem_addr = 0; dmem_wdata = 0; dmem_be = 4'b1111;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst_n = 1'b1;

            fetch_idx = 0; retired = 0; cycles = 0;
            ex_valid = 0; ex_mem = 0; ex_store = 0; ex_idx = 0;
            n_mem = 0; exp_conf = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (is_mem(i, k)) begin
                    n_mem = n_mem + 1;
                    if (i < N - 1) exp_conf = exp_conf + 1;
                end
            end

            while (retired < N) begin
                // Fetch stage: request the next instruction
                imem_req  = (fetch_idx < N);
                imem_addr = fetch_idx * 4;
                // Execute stage: data access of the instruction being executed
                dmem_re    = ex_valid && ex_mem && !ex_store;
                dmem_we    = ex_valid && ex_mem &&  ex_store;
                dmem_addr  = DBASE + (ex_idx % 256) * 4;
                dmem_wdata = ex_idx;
                #1;
                @(posedge clk); #1;
                cycles = cycles + 1;
                // Execute always completes (dmem_ready is always 1)
                if (ex_valid) retired = retired + 1;
                // Fetch completes only when imem_ready was high
                if (imem_req && imem_ready) begin
                    ex_valid  = 1;
                    ex_idx    = fetch_idx;
                    ex_mem    = is_mem(fetch_idx, k);
                    ex_store  = fetch_idx[0];   // odd mem instr = store, even = load
                    fetch_idx = fetch_idx + 1;
                end else begin
                    ex_valid = 0;                // bubble
                end
                // Note: imem_ready was sampled before the edge (inputs held stable)
            end

            exp_cycles = N + 1 + exp_conf;
            $display("--- density %0d%% : %0d load/stores ---", k * 25, n_mem);
            check(conflict_count, exp_conf,   "  conflict_count matches model");
            check(cycles,         exp_cycles, "  shared cycles = N + 1 + conflicts");
            $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d.%02d,%0d.%02d,%0d",
                      k * 25, N, n_mem, conflict_count, cycles, N + 1,
                      cycles / N, (cycles * 100 / N) % 100,
                      (N + 1) / N, ((N + 1) * 100 / N) % 100,
                      (cycles - (N + 1)) * 100 / (N + 1));
        end

        $fclose(csv_fd);
        $display("================================================================");
        $display(" tb_density: %0d passed, %0d failed  (results: waves/density_sweep.csv)",
                 tests_passed, tests_failed);
        $display("================================================================");
        if (tests_failed != 0) $fatal(1, "tb_density FAILED");
        $finish;
    end

endmodule
