`timescale 1ns / 1ps

// Testbench for address decoder
module tb_decoder;

    reg  [31:0] addr;
    wire        sel_dmem;
    wire        sel_imem_region;
    wire        addr_error;
    wire [9:0]  word_index;

    integer pass_count = 0;
    integer fail_count = 0;

    addr_decoder uut (
        .addr            (addr),
        .sel_dmem        (sel_dmem),
        .sel_imem_region (sel_imem_region),
        .addr_error      (addr_error),
        .word_index      (word_index)
    );

    // helper to verify outputs
    task check_decoder(
        input [31:0] test_addr,
        input        exp_sel_dmem,
        input        exp_sel_imem,
        input        exp_addr_error,
        input [9:0]  exp_word_index,
        input [127:0] test_name
    );
        begin
            addr = test_addr;
            #5;

            if (sel_dmem === exp_sel_dmem &&
                sel_imem_region === exp_sel_imem &&
                addr_error === exp_addr_error &&
                word_index === exp_word_index) begin
                $display("[PASS] %s | Addr: 0x%08h -> sel_dmem=%b, sel_imem=%b, err=%b, idx=%0d",
                         test_name, test_addr, sel_dmem, sel_imem_region, addr_error, word_index);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s | Addr: 0x%08h | Expected: sel_d=%b, sel_i=%b, err=%b, idx=%0d | Got: sel_d=%b, sel_i=%b, err=%b, idx=%0d",
                         test_name, test_addr, exp_sel_dmem, exp_sel_imem, exp_addr_error, exp_word_index,
                         sel_dmem, sel_imem_region, addr_error, word_index);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("waves/tb_decoder.vcd");
        $dumpvars(0, tb_decoder);

        $display("Testing address decoder...");

        // test in-range data memory addresses
        check_decoder(32'h1000_0000, 1'b1, 1'b0, 1'b0, 10'd0,    "DMEM Base 0x1000_0000");
        check_decoder(32'h1000_0004, 1'b1, 1'b0, 1'b0, 10'd1,    "DMEM Word 1 0x1000_0004");
        check_decoder(32'h1000_0020, 1'b1, 1'b0, 1'b0, 10'd8,    "DMEM Word 8 0x1000_0020");
        check_decoder(32'h1000_0400, 1'b1, 1'b0, 1'b0, 10'd256,  "DMEM Word 256 0x1000_0400");
        check_decoder(32'h1000_0800, 1'b1, 1'b0, 1'b0, 10'd512,  "DMEM Word 512 0x1000_0800");
        check_decoder(32'h1000_0FF8, 1'b1, 1'b0, 1'b0, 10'd1022, "DMEM Word 1022 0x1000_0FF8");
        check_decoder(32'h1000_0FFC, 1'b1, 1'b0, 1'b0, 10'd1023, "DMEM Top Word 0x1000_0FFC");

        // test instruction memory addresses (should flag error)
        check_decoder(32'h0000_0000, 1'b0, 1'b1, 1'b1, 10'd0,    "IMEM Base 0x0000_0000");
        check_decoder(32'h0000_0004, 1'b0, 1'b1, 1'b1, 10'd1,    "IMEM Word 1 0x0000_0004");
        check_decoder(32'h0000_0FFC, 1'b0, 1'b1, 1'b1, 10'd1023, "IMEM Top 0x0000_0FFC");

        // test invalid / out-of-range addresses
        check_decoder(32'h0FFF_FFFC, 1'b0, 1'b0, 1'b1, 10'd1023, "Below DMEM 0x0FFF_FFFC");
        check_decoder(32'h1000_1000, 1'b0, 1'b0, 1'b1, 10'd0,    "DMEM Upper Boundary 0x1000_1000");
        check_decoder(32'h1000_1004, 1'b0, 1'b0, 1'b1, 10'd1,    "Above DMEM 0x1000_1004");
        check_decoder(32'h2000_0000, 1'b0, 1'b0, 1'b1, 10'd0,    "Far Region 0x2000_0000");
        check_decoder(32'h8000_0000, 1'b0, 1'b0, 1'b1, 10'd0,    "High Region 0x8000_0000");
        check_decoder(32'hFFFF_FFFC, 1'b0, 1'b0, 1'b1, 10'd1023, "Max Word 0xFFFF_FFFC");

        $display("tb_decoder results: %0d passed, %0d failed", pass_count, fail_count);

        if (fail_count > 0) begin
            $finish(1);
        end else begin
            $finish(0);
        end
    end

endmodule
