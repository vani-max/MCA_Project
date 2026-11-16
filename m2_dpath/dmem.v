`timescale 1ns / 1ps

// 1024-word RAM with byte-level write control
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

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    // zero out memory on startup and load hex file if passed
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'h0000_0000;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // write on clock edge, updating only enabled bytes
    always @(posedge clk) begin
        if (we) begin
            if (be[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
            if (be[1]) mem[addr][15: 8] <= wdata[15: 8];
            if (be[2]) mem[addr][23:16] <= wdata[23:16];
            if (be[3]) mem[addr][31:24] <= wdata[31:24];
        end
    end

    // read directly from memory
    assign rdata = mem[addr];

endmodule
