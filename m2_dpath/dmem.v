// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M2 - Data Path
// File: dmem.v (Data Memory Core)
// =============================================================================
// Contract Specification (Section 4.1 & Section 5):
//   Parameters:
//     - INIT_FILE : Optional path to 32-bit hex file loaded via $readmemh
//     - DEPTH     : Number of 32-bit words (default 1024 = 4 KB)
//
//   Ports:
//     - clk       : System clock (rising edge active)
//     - addr      : 10-bit word index (0 to 1023)
//     - wdata     : 32-bit write data word
//     - we        : Write enable (active-high synchronous)
//     - be        : 4-bit byte enables (be[0]->byte0, be[3]->byte3)
//     - rdata     : 32-bit read data word (combinational read)
//
// Write Rule (Section 3.2):
//   A store takes effect at the rising clock edge when we is high.
//   Individual bytes are modified according to be[3:0], supporting
//   byte, halfword, and word operations via read-modify-write masking.
// =============================================================================

`timescale 1ns / 1ps

module dmem #(
    parameter INIT_FILE = "",
    parameter DEPTH     = 1024
)(
    input  wire        clk,
    input  wire [9:0]  addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire [3:0]  be,
    output wire [31:0] rdata
);

    // 1024 x 32-bit memory array
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    // Initialization:
    // Pre-initialize memory array to 0x0000_0000 to avoid any unknown ('X') states.
    // Optionally load initial data from hex file if provided.
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'h0000_0000;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Synchronous write with byte-enable masking
    always @(posedge clk) begin
        if (we) begin
            if (be[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
            if (be[1]) mem[addr][15: 8] <= wdata[15: 8];
            if (be[2]) mem[addr][23:16] <= wdata[23:16];
            if (be[3]) mem[addr][31:24] <= wdata[31:24];
        end
    end

    // Combinational read: continuous read of the addressed memory word
    assign rdata = mem[addr];

endmodule
