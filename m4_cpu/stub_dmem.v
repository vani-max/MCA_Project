// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: stub_dmem.v (Behavioural Data Memory Stub)
// =============================================================================
// Specifications (Section 5 / M4):
//   - Behavioural data memory model for independent M4 testing.
//   - Parameter INIT_FILE: path to initial data hex loaded via $readmemh.
//   - Parameter RANDOM_STALLS:
//       0 = ideal zero-wait-state memory (dmem_ready always 1).
//       1 = pseudo-randomly deasserts dmem_ready to verify CPU stall handling.
//   - Synchronous write with byte enables (Section 3.2 write rule).
//   - Combinational read matching Section 3.2 contract.
// =============================================================================

`timescale 1ns / 1ps

module stub_dmem #(
    parameter INIT_FILE     = "",
    parameter DEPTH         = 1024,
    parameter RANDOM_STALLS = 0,
    parameter [31:0] SEED   = 32'h8765_4321
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU data port (Section 3.2)
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire        dmem_re,
    input  wire        dmem_we,
    input  wire [3:0]  dmem_be,
    output wire [31:0] dmem_rdata,
    output reg         dmem_ready
);

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'h0000_0000;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Address decode (Data region: 0x1000_0000 .. 0x1000_0FFF)
    wire in_range = (dmem_addr >= 32'h1000_0000) && (dmem_addr < 32'h1000_1000);
    wire [9:0] word_index = dmem_addr[11:2];

    // Synchronous write (Section 3.2: takes effect only when dmem_we && dmem_ready)
    always @(posedge clk) begin
        if (rst_n && dmem_we && dmem_ready && in_range) begin
            if (dmem_be[0]) mem[word_index][ 7: 0] <= dmem_wdata[ 7: 0];
            if (dmem_be[1]) mem[word_index][15: 8] <= dmem_wdata[15: 8];
            if (dmem_be[2]) mem[word_index][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) mem[word_index][31:24] <= dmem_wdata[31:24];
        end
    end

    // Combinational read
    assign dmem_rdata = (dmem_ready && dmem_re && in_range) ? mem[word_index] : 32'h0000_0000;

    // Pseudo-random ready generator using 32-bit Galois LFSR
    reg [31:0] lfsr;
    reg        last_was_stall;
    wire       access_req = dmem_re || dmem_we;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr           <= SEED;
            dmem_ready     <= 1'b1;
            last_was_stall <= 1'b0;
        end else if (RANDOM_STALLS) begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

            if (last_was_stall) begin
                // Guarantee forward progress: ready after any stall cycle
                dmem_ready     <= 1'b1;
                last_was_stall <= 1'b0;
            end else if (access_req && (lfsr[3:1] == 3'b010 || lfsr[3:1] == 3'b101)) begin
                // ~25% probability of a 1-cycle stall during memory access
                dmem_ready     <= 1'b0;
                last_was_stall <= 1'b1;
            end else begin
                dmem_ready     <= 1'b1;
                last_was_stall <= 1'b0;
            end
        end else begin
            dmem_ready     <= 1'b1;
            last_was_stall <= 1'b0;
        end
    end

endmodule
