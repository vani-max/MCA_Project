
`timescale 1ns/1ps

module tb_system;

    reg clk = 0;
    reg rst_n = 0;

    always #5 clk = ~clk;

    // Program and data file paths supplied at runtime
    reg [1023:0] program_file;
    reg [1023:0] data_file;

    // Harvard outputs
    wire h_halt;
    wire h_fault;

    // Shared-memory outputs
    wire s_halt;
    wire [31:0] s_conflict_count;
    wire s_fault;

    integer i;
    integer cycles;
    integer errors;
    integer data_enabled;

    // ------------------------------------------------
    // Harvard architecture
    // ------------------------------------------------

    top_harvard #(
        .PROGRAM_FILE(""),
        .DATA_FILE("")
    ) dut_harvard (
        .clk         (clk),
        .rst_n       (rst_n),
        .halt        (h_halt),
        .access_fault(h_fault)
    );

    // ------------------------------------------------
    // Shared-memory architecture
    // ------------------------------------------------

    top_shared #(
        .PROGRAM_FILE(""),
        .DATA_FILE("")
    ) dut_shared (
        .clk           (clk),
        .rst_n         (rst_n),
        .halt          (s_halt),
        .conflict_count(s_conflict_count),
        .access_fault  (s_fault)
    );

    // ------------------------------------------------
    // Test execution
    // ------------------------------------------------

    initial begin

        program_file = "";
        data_file = "";
        data_enabled = 0;
        cycles = 0;
        errors = 0;

        if (!$value$plusargs("PROGRAM=%s", program_file)) begin
            $display("ERROR: Provide +PROGRAM=path/to/program.hex");
            $finish;
        end

        if ($value$plusargs("DATA=%s", data_file))
            data_enabled = 1;

        $display("==============================================");
        $display(" M5 HARVARD VS SHARED MEMORY TEST");
        $display("==============================================");
        $display("Program: %0s", program_file);

        // Load program into Harvard instruction memory
        $readmemh(
            program_file,
            dut_harvard.imem_inst.u_imem.mem
        );

        // Load same program into shared memory
        $readmemh(
            program_file,
            dut_shared.shared_mem_inst.u_core.mem,
            0,
            1023
        );

        // Load initial data if supplied
        if (data_enabled) begin

            $display("Data file: %0s", data_file);

            $readmemh(
                data_file,
                dut_harvard.dmem_inst.mem_inst.mem
            );

            $readmemh(
                data_file,
                dut_shared.shared_mem_inst.u_core.mem,
                1024,
                2047
            );

        end

        // Apply reset
        rst_n = 0;
        repeat (3) @(posedge clk);
        #1;
        rst_n = 1;

        // Wait for both processors to halt
        while ((!h_halt || !s_halt) && cycles < 10000) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end

        $display("----------------------------------------------");
        $display("Execution cycles: %0d", cycles);
        $display("Harvard HALT: %b", h_halt);
        $display("Shared HALT : %b", s_halt);
        $display("Shared memory conflicts: %0d", s_conflict_count);

        // Check that both processors halted
        if (!h_halt || !s_halt) begin
            $display("[FAIL] Timeout: one or both processors did not halt.");
            errors = errors + 1;
        end

        // Compare all 32 registers
        for (i = 0; i < 32; i = i + 1) begin

            if (dut_harvard.cpu_inst.rf_inst.regs[i] !==
                dut_shared.cpu_inst.rf_inst.regs[i]) begin

                $display(
                    "[FAIL] Register x%0d mismatch: Harvard=%08h Shared=%08h",
                    i,
                    dut_harvard.cpu_inst.rf_inst.regs[i],
                    dut_shared.cpu_inst.rf_inst.regs[i]
                );

                errors = errors + 1;
            end

        end

        // Compare all 1024 data-memory words
        for (i = 0; i < 1024; i = i + 1) begin

            if (dut_harvard.dmem_inst.mem_inst.mem[i] !==
                dut_shared.shared_mem_inst.u_core.mem[i + 1024]) begin

                $display(
                    "[FAIL] Data memory word %0d mismatch: Harvard=%08h Shared=%08h",
                    i,
                    dut_harvard.dmem_inst.mem_inst.mem[i],
                    dut_shared.shared_mem_inst.u_core.mem[i + 1024]
                );

                errors = errors + 1;
            end

        end

        // Check memory access faults
        if (h_fault || s_fault) begin
            $display("[FAIL] Memory access fault detected.");
            errors = errors + 1;
        end

        $display("----------------------------------------------");

        if (errors == 0) begin
            $display("[PASS] Harvard and Shared results match!");
            $display("[PASS] Register files match.");
            $display("[PASS] Data memories match.");
        end else begin
            $display("[FAIL] Total mismatches: %0d", errors);
        end

        $display("==============================================");

        $finish;
    end

    // Waveform output
    initial begin
        $dumpfile("system.vcd");
        $dumpvars(0, tb_system);
    end

endmodule
