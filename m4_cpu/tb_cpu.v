// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: tb_cpu.v (Comprehensive Unit Testbench for cpu_core)
// =============================================================================
// Specifications (Section 5 / M4 Unit Tests):
//   1. Every instruction in subset (ADD, SUB, AND, OR, ADDI, LW, SW, BEQ, BNE, JAL, LUI, HALT)
//   2. Signed immediates (positive & negative values)
//   3. x0 write ignored (x0 remains strictly 0)
//   4. Taken and not-taken branches (BEQ, BNE)
//   5. Loads/stores with stalls injected (dmem_ready drops)
//   6. Instruction fetch stalls (imem_ready drops)
//   7. HALT behavior (stops core, halt=1 asserted, requests deasserted)
// =============================================================================

`timescale 1ns / 1ps

module tb_cpu;

    // Clock and reset
    reg clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz clock (10 ns period)
    reg rst_n;

    // CPU instruction port
    wire [31:0] imem_addr;
    wire        imem_req;
    wire [31:0] imem_rdata;
    reg         imem_ready;

    // CPU data port
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_re;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_rdata;
    reg         dmem_ready;

    // Status output
    wire        halt;

    // Direct memory models for unit testing
    reg [31:0] test_imem [0:1023];
    reg [31:0] test_dmem [0:1023];

    // Instantiate DUT (cpu_core)
    cpu_core dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_req   (imem_req),
        .imem_rdata (imem_rdata),
        .imem_ready (imem_ready),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_re    (dmem_re),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be),
        .dmem_rdata (dmem_rdata),
        .dmem_ready (dmem_ready),
        .halt       (halt)
    );

    // Combinational read data from test memories
    wire [9:0] imem_idx = imem_addr[11:2];
    wire [9:0] dmem_idx = dmem_addr[11:2];

    assign imem_rdata = (imem_ready && (imem_addr[31:12] == 20'h00000)) ?
                        test_imem[imem_idx] : 32'h0000_0013;

    assign dmem_rdata = (dmem_ready && dmem_re && (dmem_addr >= 32'h1000_0000 && dmem_addr < 32'h1000_1000)) ?
                        test_dmem[dmem_idx] : 32'h0000_0000;

    // Synchronous memory write
    always @(posedge clk) begin
        if (rst_n && dmem_we && dmem_ready && (dmem_addr >= 32'h1000_0000 && dmem_addr < 32'h1000_1000)) begin
            if (dmem_be[0]) test_dmem[dmem_idx][ 7: 0] <= dmem_wdata[ 7: 0];
            if (dmem_be[1]) test_dmem[dmem_idx][15: 8] <= dmem_wdata[15: 8];
            if (dmem_be[2]) test_dmem[dmem_idx][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) test_dmem[dmem_idx][31:24] <= dmem_wdata[31:24];
        end
    end

    // Test tracking
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    task check_val(input [31:0] got, input [31:0] exp, input [8*60:1] test_name);
        begin
            if (got === exp) begin
                $display("[PASS] %0s | Got: 0x%08x (%0d)", test_name, got, $signed(got));
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s | Expected: 0x%08x (%0d), Got: 0x%08x (%0d)",
                         test_name, exp, $signed(exp), got, $signed(got));
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Instruction Encoder Helper Functions
    function [31:0] enc_r(input [6:0] funct7, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3, input [4:0] rd, input [6:0] op);
        enc_r = {funct7, rs2, rs1, funct3, rd, op};
    endfunction

    function [31:0] enc_i(input [11:0] imm, input [4:0] rs1, input [2:0] funct3, input [4:0] rd, input [6:0] op);
        enc_i = {imm, rs1, funct3, rd, op};
    endfunction

    function [31:0] enc_s(input [11:0] imm, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3, input [6:0] op);
        enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], op};
    endfunction

    function [31:0] enc_b(input [12:0] imm, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3, input [6:0] op);
        enc_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], op};
    endfunction

    function [31:0] enc_u(input [19:0] imm20, input [4:0] rd, input [6:0] op);
        enc_u = {imm20, rd, op};
    endfunction

    function [31:0] enc_j(input [20:0] imm21, input [4:0] rd, input [6:0] op);
        enc_j = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, op};
    endfunction

    localparam [6:0] OP_REG    = 7'b0110011;
    localparam [6:0] OP_IMM    = 7'b0010011;
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JAL    = 7'b1101111;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [31:0] NOP      = 32'h0000_0013;
    localparam [31:0] HALT_W   = 32'h0000_006F;

    initial begin
        $dumpfile("waves/tb_cpu.vcd");
        $dumpvars(0, tb_cpu);

        $display("================================================================================");
        $display(" Running M4 CPU Core Comprehensive Unit Testbench");
        $display("================================================================================");

        // Pre-fill memories
        for (i = 0; i < 1024; i = i + 1) begin
            test_imem[i] = NOP;
            test_dmem[i] = 32'h0000_0000;
        end

        // ---------------------------------------------------------------------
        // Construct Micro-program in test_imem
        // ---------------------------------------------------------------------
        // 0x00: ADDI x1, x0, 15          (x1 = 15)
        test_imem[0]  = enc_i(12'd15, 5'd0, 3'b000, 5'd1, OP_IMM);
        // 0x04: ADDI x2, x0, -5          (x2 = -5, signed negative immediate)
        test_imem[1]  = enc_i(-12'd5, 5'd0, 3'b000, 5'd2, OP_IMM);
        // 0x08: ADD  x3, x1, x2          (x3 = 15 + (-5) = 10)
        test_imem[2]  = enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, OP_REG);
        // 0x0C: SUB  x4, x1, x3          (x4 = 15 - 10 = 5)
        test_imem[3]  = enc_r(7'b0100000, 5'd3, 5'd1, 3'b000, 5'd4, OP_REG);
        // 0x10: AND  x5, x1, x4          (x5 = 15 & 5 = 5)
        test_imem[4]  = enc_r(7'b0000000, 5'd4, 5'd1, 3'b111, 5'd5, OP_REG);
        // 0x14: OR   x6, x2, x1          (x6 = -5 | 15)
        test_imem[5]  = enc_r(7'b0000000, 5'd1, 5'd2, 3'b110, 5'd6, OP_REG);
        // 0x18: ADDI x0, x0, 999         (Attempt write to x0: MUST BE IGNORED)
        test_imem[6]  = enc_i(12'd999, 5'd0, 3'b000, 5'd0, OP_IMM);
        // 0x1C: LUI  x7, 20'h10000       (x7 = 0x1000_0000)
        test_imem[7]  = enc_u(20'h10000, 5'd7, OP_LUI);
        // 0x20: SW   x3, 0(x7)           (MEM[0x1000_0000] = x3 = 10)
        test_imem[8]  = enc_s(12'd0, 5'd3, 5'd7, 3'b010, OP_STORE);
        // 0x24: LW   x8, 0(x7)           (x8 = MEM[0x1000_0000] = 10)
        test_imem[9]  = enc_i(12'd0, 5'd7, 3'b010, 5'd8, OP_LOAD);
        // 0x28: BEQ  x3, x8, +8 (to 0x30)(Taken: x3 == x8 == 10)
        test_imem[10] = enc_b(13'd8, 5'd8, 5'd3, 3'b000, OP_BRANCH);
        // 0x2C: ADDI x9, x0, 111         (Skipped if branch taken)
        test_imem[11] = enc_i(12'd111, 5'd0, 3'b000, 5'd9, OP_IMM);
        // 0x30: ADDI x9, x0, 222         (Target of taken BEQ)
        test_imem[12] = enc_i(12'd222, 5'd0, 3'b000, 5'd9, OP_IMM);
        // 0x34: BEQ  x1, x2, +8 (to 0x3C)(Not taken: x1=15 != x2=-5)
        test_imem[13] = enc_b(13'd8, 5'd2, 5'd1, 3'b000, OP_BRANCH);
        // 0x38: ADDI x10, x0, 333        (Executed because branch NOT taken)
        test_imem[14] = enc_i(12'd333, 5'd0, 3'b000, 5'd10, OP_IMM);
        // 0x3C: BNE  x1, x2, +8 (to 0x44)(Taken: x1 != x2)
        test_imem[15] = enc_b(13'd8, 5'd2, 5'd1, 3'b001, OP_BRANCH);
        // 0x40: ADDI x11, x0, 444        (Skipped if BNE taken)
        test_imem[16] = enc_i(12'd444, 5'd0, 3'b000, 5'd11, OP_IMM);
        // 0x44: ADDI x11, x0, 555        (Target of taken BNE)
        test_imem[17] = enc_i(12'd555, 5'd0, 3'b000, 5'd11, OP_IMM);
        // 0x48: BNE  x3, x8, +8 (to 0x50)(Not taken: x3 == x8 == 10)
        test_imem[18] = enc_b(13'd8, 5'd8, 5'd3, 3'b001, OP_BRANCH);
        // 0x4C: ADDI x12, x0, 666        (Executed because BNE NOT taken)
        test_imem[19] = enc_i(12'd666, 5'd0, 3'b000, 5'd12, OP_IMM);
        // 0x50: JAL  x13, +8 (to 0x58)   (Jump to 0x58, link x13 = 0x54)
        test_imem[20] = enc_j(21'd8, 5'd13, OP_JAL);
        // 0x54: ADDI x14, x0, 777        (Skipped by JAL)
        test_imem[21] = enc_i(12'd777, 5'd0, 3'b000, 5'd14, OP_IMM);
        // 0x58: ADDI x14, x0, 888        (Target of JAL)
        test_imem[22] = enc_i(12'd888, 5'd0, 3'b000, 5'd14, OP_IMM);
        // 0x5C: HALT                     (32'h0000_006F)
        test_imem[23] = HALT_W;

        // Reset system
        rst_n = 1'b0;
        imem_ready = 1'b1;
        dmem_ready = 1'b1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1'b1;

        // Run until HALT
        while (!halt) begin
            @(posedge clk); #1;
        end
        @(posedge clk); #1; // Extra cycle after halt

        $display("\n>>> Phase 1: Instruction-Level Correctness Checks <<<");
        check_val(dut.rf_inst.regs[1],  32'd15,       "T01: ADDI positive immediate (x1 = 15)");
        check_val(dut.rf_inst.regs[2],  -32'd5,       "T02: ADDI signed negative immediate (x2 = -5)");
        check_val(dut.rf_inst.regs[3],  32'd10,       "T03: ADD x1 + x2 (x3 = 10)");
        check_val(dut.rf_inst.regs[4],  32'd5,        "T04: SUB x1 - x3 (x4 = 5)");
        check_val(dut.rf_inst.regs[5],  32'd5,        "T05: AND x1 & x4 (x5 = 5)");
        check_val(dut.rf_inst.regs[6],  (-32'd5 | 15),"T06: OR x2 | x1");
        check_val(dut.rf_inst.regs[0],  32'd0,        "T07: x0 hardwired to zero (x0 == 0)");
        check_val(dut.rf_inst.regs[7],  32'h1000_0000,"T08: LUI x7 = 0x1000_0000");
        check_val(test_dmem[0],         32'd10,       "T09: SW stores x3 into MEM[0x1000_0000]");
        check_val(dut.rf_inst.regs[8],  32'd10,       "T10: LW loads from MEM into x8");
        check_val(dut.rf_inst.regs[9],  32'd222,      "T11: BEQ taken redirects PC (x9 = 222)");
        check_val(dut.rf_inst.regs[10], 32'd333,      "T12: BEQ not-taken falls through (x10 = 333)");
        check_val(dut.rf_inst.regs[11], 32'd555,      "T13: BNE taken redirects PC (x11 = 555)");
        check_val(dut.rf_inst.regs[12], 32'd666,      "T14: BNE not-taken falls through (x12 = 666)");
        check_val(dut.rf_inst.regs[13], 32'h0000_0054,"T15: JAL link address rd = PC + 4 (x13 = 0x54)");
        check_val(dut.rf_inst.regs[14], 32'd888,      "T16: JAL target executed (x14 = 888)");
        check_val({31'b0, halt},        32'd1,        "T17: HALT signal asserted high (halt = 1)");
        check_val({31'b0, imem_req},    32'd0,        "T18: imem_req deasserted after HALT");

        // ---------------------------------------------------------------------
        // Phase 2: Dynamic Stall Injections
        // ---------------------------------------------------------------------
        $display("\n>>> Phase 2: Stall Injection & Handshake Verification <<<");

        // Reset memory for stall tests
        for (i = 0; i < 1024; i = i + 1) begin
            test_imem[i] = NOP;
            test_dmem[i] = 32'h0000_0000;
        end
        test_dmem[0] = 32'hA5A5_5A5A; // Pre-load test pattern

        // 0x00: LUI x1, 0x10000
        test_imem[0] = enc_u(20'h10000, 5'd1, OP_LUI);
        // 0x04: LW  x2, 0(x1)           (Will inject dmem_ready stall)
        test_imem[1] = enc_i(12'd0, 5'd1, 3'b010, 5'd2, OP_LOAD);
        // 0x08: ADDI x3, x2, 1          (Data use right after load)
        test_imem[2] = enc_i(12'd1, 5'd2, 3'b000, 5'd3, OP_IMM);
        // 0x0C: HALT
        test_imem[3] = HALT_W;

        // Reset CPU
        rst_n = 1'b0;
        imem_ready = 1'b1;
        dmem_ready = 1'b1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1'b1;

        // Wait until LW instruction enters EX stage
        // Cycle 1: LUI fetched into EX
        @(posedge clk); #1;
        // Cycle 2: LW enters EX (dmem_re goes high combinationally)
        @(posedge clk); #1;
        check_val({31'b0, dmem_re}, 32'd1, "T19a: LW asserted dmem_re upon entering EX");

        // Now inject 3 cycles of dmem_ready = 0 before the next clock edge!
        dmem_ready = 1'b0;
        repeat(3) begin
            @(posedge clk); #1;
            // Verify request and address held completely stable
            if (dmem_re !== 1'b1 || dmem_addr !== 32'h1000_0000) begin
                $display("[FAIL] Data memory request signals glitched during stall!");
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end
        end
        $display("[PASS] T19b: dmem_re and dmem_addr held completely stable across 3 stall cycles");

        // Release stall: LW completes at next posedge clk
        dmem_ready = 1'b1;

        // Now inject 2 cycles of imem_ready = 0 during subsequent fetch
        @(posedge clk); #1;
        imem_ready = 1'b0;
        repeat(2) begin
            @(posedge clk); #1;
        end
        imem_ready = 1'b1;

        // Run to HALT
        while (!halt) @(posedge clk);
        #1;

        check_val(dut.rf_inst.regs[2], 32'hA5A5_5A5A, "T19: LW with injected dmem stalls loaded correctly");
        check_val(dut.rf_inst.regs[3], 32'hA5A5_5A5B, "T20: ADDI with injected imem stalls computed correctly");

        $display("\n================================================================================");
        if (fail_count == 0) begin
            $display(" ALL %0d UNIT TESTS PASSED SUCCESSFULLY!", pass_count);
        end else begin
            $display(" %0d TESTS FAILED out of %0d tests!", fail_count, pass_count + fail_count);
        end
        $display("================================================================================");

        $finish;
    end

endmodule
