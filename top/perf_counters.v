
`timescale 1ns/1ps

module perf_counters (
    input wire clk,
    input wire rst_n,

    input wire imem_req,
    input wire imem_ready,

    input wire dmem_re,
    input wire dmem_we,
    input wire dmem_ready,

    input wire halt
);

    reg [31:0] cycle_count;
    reg [31:0] instruction_count;
    reg [31:0] stall_count;
    reg [31:0] load_count;
    reg [31:0] store_count;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            cycle_count      <= 0;
            instruction_count <= 0;
            stall_count      <= 0;
            load_count       <= 0;
            store_count      <= 0;
        end

        else if (!halt) begin

            // Count active execution cycles
            cycle_count <= cycle_count + 1;

            // Count successfully completed instruction fetches
            if (imem_req && imem_ready)
                instruction_count <= instruction_count + 1;

            // Count cycles where a memory request is stalled
            if ((imem_req && !imem_ready) ||
                ((dmem_re || dmem_we) && !dmem_ready))
                stall_count <= stall_count + 1;

            // Count completed load operations
            if (dmem_re && dmem_ready)
                load_count <= load_count + 1;

            // Count completed store operations
            if (dmem_we && dmem_ready)
                store_count <= store_count + 1;

        end

        else begin

            // Print one machine-readable summary at HALT
            $display(
                "SUMMARY cycles=%0d instructions=%0d stalls=%0d loads=%0d stores=%0d",
                cycle_count,
                instruction_count,
                stall_count,
                load_count,
                store_count
            );

        end

    end

endmodule
