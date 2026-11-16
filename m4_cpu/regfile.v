// =============================================================================
// Project 9: Instruction and Data Memory Hierarchy
// Team Member: M4 - Processor Core and Test Programs
// File: regfile.v (32 x 32-bit RISC-V Register File)
// =============================================================================
// Specifications (Section 5 / M4):
//   - 32 general-purpose registers (x0 to x31), each 32-bit wide.
//   - x0 is hardwired to 0: writes to x0 are discarded; reads always return 0.
//   - Synchronous write on rising clock edge when rd_we is asserted.
//   - Active-low asynchronous reset rst_n clears all registers.
//   - Combinational reads for rs1 and rs2 with internal forwarding.
// =============================================================================

`timescale 1ns / 1ps

module regfile (
    input  wire        clk,
    input  wire        rst_n,

    // Read port 1
    input  wire [4:0]  rs1_addr,
    output wire [31:0] rs1_data,

    // Read port 2
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs2_data,

    // Write port
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    input  wire        rd_we
);

    reg [31:0] regs [0:31];
    integer i;

    // Synchronous write and asynchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'h0000_0000;
            end
        end else if (rd_we && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

    // Combinational read of register array.
    // Register x0 is hardwired to 0.
    // Registers update synchronously on posedge clk.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'h0000_0000 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'h0000_0000 : regs[rs2_addr];

endmodule
