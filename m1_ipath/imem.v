// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M1 - Instruction Path
// File: imem.v (Instruction Memory)
// =============================================================================
// Contract Specification (Section 4.1 & Section 5):
//   Parameters:
//     - MEM_FILE : Path to 32-bit hex file loaded via $readmemh (default "")
//     - DEPTH    : Number of 32-bit words (default 1024 = 4 KB)
//
//   Ports:
//     - addr     : 32-bit byte address from CPU/PC
//     - rdata    : 32-bit instruction word, combinational read
//
//   Addressing & Memory Map:
//     - Base Address: 0x0000_0000
//     - Size: 4 KB (1024 words, spanning 0x0000_0000 to 0x0000_0FFF)
//     - Word Index: addr[11:2]
//     - Out-of-range: addr[31:12] != 20'h00000 -> returns 32'h0000_0013 (NOP)
// =============================================================================

`timescale 1ns / 1ps

module imem #(
    parameter MEM_FILE = "",
    parameter DEPTH    = 1024
)(
    input  wire [31:0] addr,
    output wire [31:0] rdata
);

    // 1024 x 32-bit memory array
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    // Initialization:
    // Pre-initialize all memory entries to RISC-V NOP (addi x0, x0, 0 = 32'h0000_0013)
    // to guarantee no unknown ('X') values occur.
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'h0000_0013;
        end

        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, mem);
        end
    end

    // Address range validation:
    // Base 0x0000_0000, 4 KB range: addresses 0x0000_0000 .. 0x0000_0FFF
    // Any address where addr[31:12] != 20'h00000 is considered out-of-range.
    wire in_range = (addr[31:12] == 20'h00000);
    wire [9:0] word_index = addr[11:2];

    // Combinational read: returns valid instruction word or NOP (32'h0000_0013)
    assign rdata = in_range ? mem[word_index] : 32'h0000_0013;

endmodule
