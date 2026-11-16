`timescale 1ns / 1ps

// Controller connecting CPU to data memory
module dmem_ctrl #(
    parameter INIT_FILE = "",
    parameter DEPTH     = 1024
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU data bus
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire        dmem_re,
    input  wire        dmem_we,
    input  wire [3:0]  dmem_be,
    output wire [31:0] dmem_rdata,
    output wire        dmem_ready,

    output reg         access_fault
);

    // harvard memory is always ready (no wait cycles)
    assign dmem_ready = 1'b1;

    wire        sel_dmem;
    wire        sel_imem_region;
    wire        addr_error;
    wire [9:0]  word_index;

    // decode address to get index and check range
    addr_decoder decoder_inst (
        .addr            (dmem_addr),
        .sel_dmem        (sel_dmem),
        .sel_imem_region (sel_imem_region),
        .addr_error      (addr_error),
        .word_index      (word_index)
    );

    // only write if write is enabled and address is valid
    wire mem_we = dmem_we && dmem_ready && !addr_error;
    wire [31:0] mem_rdata_raw;

    dmem #(
        .INIT_FILE (INIT_FILE),
        .DEPTH     (DEPTH)
    ) mem_inst (
        .clk   (clk),
        .addr  (word_index),
        .wdata (dmem_wdata),
        .we    (mem_we),
        .be    (dmem_be),
        .rdata (mem_rdata_raw)
    );

    // return memory data on valid read, 0 if out of range or not reading
    assign dmem_rdata = (dmem_re && !addr_error) ? mem_rdata_raw : 32'h0000_0000;

    // latch error flag if someone touches bad address, stays until reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            access_fault <= 1'b0;
        end else if ((dmem_re || dmem_we) && addr_error) begin
            access_fault <= 1'b1;
        end
    end

endmodule
