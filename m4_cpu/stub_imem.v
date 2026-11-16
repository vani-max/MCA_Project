// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: stub_imem.v (Behavioural Instruction Memory Stub)
// =============================================================================
// Specifications (Section 5 / M4):
//   - Behavioural instruction memory model for independent M4 testing.
//   - Parameter MEM_FILE: path to .hex program loaded via $readmemh.
//   - Parameter RANDOM_STALLS:
//       0 = ideal zero-wait-state memory (imem_ready always 1).
//       1 = pseudo-randomly deasserts imem_ready to verify CPU stall handling.
//   - Combinational read matching Section 3.1 contract.
// =============================================================================

`timescale 1ns / 1ps

module stub_imem #(
    parameter MEM_FILE      = "",
    parameter DEPTH         = 1024,
    parameter RANDOM_STALLS = 0,
    parameter [31:0] SEED   = 32'h1234_5678
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU instruction port (Section 3.1)
    input  wire [31:0] imem_addr,
    input  wire        imem_req,
    output wire [31:0] imem_rdata,
    output reg         imem_ready
);

    localparam [31:0] NOP = 32'h0000_0013;

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = NOP;
        end
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, mem);
        end
    end

    // Address decode
    wire in_range = (imem_addr[31:12] == 20'h00000);
    wire [9:0] word_index = imem_addr[11:2];

    // Combinational read data
    assign imem_rdata = (imem_ready && in_range) ? mem[word_index] : NOP;

    // Pseudo-random ready generator using 32-bit Galois LFSR
    reg [31:0] lfsr;
    reg        last_was_stall;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr           <= SEED;
            imem_ready     <= 1'b1;
            last_was_stall <= 1'b0;
        end else if (RANDOM_STALLS) begin
            // LFSR shift with feedback polynomial x^32 + x^22 + x^2 + x^1 + 1
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

            if (last_was_stall) begin
                // Guarantee forward progress: ready after any stall cycle
                imem_ready     <= 1'b1;
                last_was_stall <= 1'b0;
            end else if (imem_req && (lfsr[2:0] == 3'b001 || lfsr[2:0] == 3'b110)) begin
                // ~25% probability of a 1-cycle stall
                imem_ready     <= 1'b0;
                last_was_stall <= 1'b1;
            end else begin
                imem_ready     <= 1'b1;
                last_was_stall <= 1'b0;
            end
        end else begin
            imem_ready     <= 1'b1;
            last_was_stall <= 1'b0;
        end
    end

endmodule
