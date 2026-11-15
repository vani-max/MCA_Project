// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M2 - Data Path
// File: addr_decoder.v (Address Decoder)
// =============================================================================
// Contract Specification (Section 4.1 & Section 5):
//   Inputs:
//     - addr            : 32-bit byte address from CPU data port
//
//   Outputs:
//     - sel_dmem        : High when 0x1000_0000 <= addr < 0x1000_1000 (4 KB Data Memory)
//     - sel_imem_region : High when 0x0000_0000 <= addr < 0x0000_1000 (4 KB Instruction Memory)
//     - addr_error      : High when address is outside the valid data memory region
//     - word_index      : 10-bit word index (0 to 1023) derived from addr[11:2]
//
// Memory Map Reference:
//   - Instruction Memory : 0x0000_0000 - 0x0000_0FFF (4 KB, 1024 words)
//   - Data Memory        : 0x1000_0000 - 0x1000_0FFF (4 KB, 1024 words)
//   - Boundary Addresses : Base = 0x1000_0000, Top = 0x1000_0FFC, Limit = 0x1000_1000
// =============================================================================

`timescale 1ns / 1ps

module addr_decoder (
    input  wire [31:0] addr,
    output wire        sel_dmem,
    output wire        sel_imem_region,
    output wire        addr_error,
    output wire [9:0]  word_index
);

    // Data memory region: 0x1000_0000 to 0x1000_0FFF (4 KB)
    // Checks if upper 20 bits match 0x10000 (addr[31:12] == 20'h10000)
    assign sel_dmem = (addr >= 32'h1000_0000) && (addr < 32'h1000_1000);

    // Instruction memory region: 0x0000_0000 to 0x0000_0FFF (4 KB)
    // Used for shared-memory variant coordination and boundary error detection
    assign sel_imem_region = (addr >= 32'h0000_0000) && (addr < 32'h0000_1000);

    // Address error: asserted if the address does NOT fall into the valid data region
    assign addr_error = !sel_dmem;

    // Word index (10 bits for 1024 words):
    // Maps byte address offset [11:0] to 32-bit word index using bits [11:2]
    assign word_index = addr[11:2];

endmodule
