`timescale 1ns / 1ps

// Address decoder for data memory
module addr_decoder (
    input  wire [31:0] addr,
    output wire        sel_dmem,
    output wire        sel_imem_region,
    output wire        addr_error,
    output wire [9:0]  word_index
);

    // check if address is within our 4KB data space (0x1000_0000 to 0x1000_0FFF)
    assign sel_dmem = (addr >= 32'h1000_0000) && (addr < 32'h1000_1000);
    assign sel_imem_region = (addr >= 32'h0000_0000) && (addr < 32'h0000_1000);

    // flag error if address is outside data range
    assign addr_error = !sel_dmem;

    // drop bottom 2 offset bits to get 10-bit word index
    assign word_index = addr[11:2];

endmodule
