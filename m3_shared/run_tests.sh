#!/usr/bin/env bash
# ==============================================================================
# Project 9: Instruction and Data Memory Hierarchy
# Member 3 (M3) - Shared-Memory (Von Neumann) Automated Test Runner
# ==============================================================================
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p waves

echo "================================================================================"
echo " Running Member 3 (M3) Shared-Memory Regression Suite"
echo "================================================================================"

echo ""
echo ">>> [1/4] Arbiter unit testbench (tb_arbiter.v)..."
iverilog -g2012 -o waves/sim_arbiter mem_arbiter.v tb_arbiter.v
vvp -n waves/sim_arbiter

echo ""
echo ">>> [2/4] Same testbench on M1's unchanged program hex (cross-team check)..."
if [ -f ../m1_ipath/prog_test.hex ]; then
    iverilog -g2012 -o waves/sim_shared_m1hex \
        -Ptb_shared_mem.PROG_FILE=\"../m1_ipath/prog_test.hex\" \
        mem_arbiter.v shared_mem.v tb_shared_mem.v
    # runs first; step 3 then regenerates the main VCD/log deliverables
    vvp -n waves/sim_shared_m1hex 2>&1 | grep -v "Not enough words" | tail -4
else
    echo "    (skipped: ../m1_ipath/prog_test.hex not found)"
fi

echo ""
echo ">>> [3/4] Shared memory system testbench (tb_shared_mem.v)..."
iverilog -g2012 -o waves/sim_shared mem_arbiter.v shared_mem.v tb_shared_mem.v
vvp -n waves/sim_shared 2>&1 | grep -v "Not enough words"

echo ""
echo ">>> [4/4] Density sweep analysis (tb_density.v)..."
iverilog -g2012 -o waves/sim_density mem_arbiter.v shared_mem.v tb_density.v
vvp -n waves/sim_density | grep -v "^\[PASS\]"

echo ""
echo "================================================================================"
echo " ALL M3 TESTS PASSED. Outputs in m3_shared/waves/:"
ls -1 waves/*.vcd waves/*.txt waves/*.csv
echo "================================================================================"
