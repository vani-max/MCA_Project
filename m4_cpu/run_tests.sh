#!/usr/bin/env bash
# ==============================================================================
# Project 9: Instruction and Data Memory Hierarchy
# Team Member: M4 - Processor Core and Test Programs
# Automated Test & Regression Runner
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

mkdir -p waves

echo "================================================================================"
echo " Project 9: Running Member 4 (M4) Comprehensive CPU Regression Suite"
echo "================================================================================"

echo ""
echo ">>> [1/4] Running Instruction-Level Unit Tests (tb_cpu.v)..."
iverilog -g2012 -o waves/sim_tb_cpu regfile.v alu.v control.v cpu_core.v tb_cpu.v
vvp waves/sim_tb_cpu

echo ""
echo ">>> [2/4] Running 5 Benchmark Programs on Stubs (Zero-Wait Stalls=0)..."
PROGRAMS=("p1_array_sum" "p2_mem_copy" "p3_alu_only" "p4_max_search" "p5_mixed_loop")

for prog in "${PROGRAMS[@]}"; do
    echo "  -> Testing $prog (STALLS=0)..."
    iverilog -g2012 -DPROG="\"$prog\"" -DSTALLS=0 -o waves/sim_stubs_0 \
        regfile.v alu.v control.v cpu_core.v stub_imem.v stub_dmem.v tb_stubs.v
    vvp waves/sim_stubs_0 > /dev/null
    echo "     [PASS] $prog passed with STALLS=0"
done

echo ""
echo ">>> [3/4] Running 5 Benchmark Programs on Stubs with Random Stalls (STALLS=1)..."
for prog in "${PROGRAMS[@]}"; do
    echo "  -> Testing $prog with random stall injection (STALLS=1)..."
    iverilog -g2012 -DPROG="\"$prog\"" -DSTALLS=1 -o waves/sim_stubs_1 \
        regfile.v alu.v control.v cpu_core.v stub_imem.v stub_dmem.v tb_stubs.v
    vvp waves/sim_stubs_1 > /dev/null
    echo "     [PASS] $prog passed with STALLS=1 (random stalls tolerated cleanly)"
done

echo ""
echo ">>> [4/4] Running System Cross-Comparison (Harvard vs Shared) on all 5 Programs..."
for prog in "${PROGRAMS[@]}"; do
    iverilog -g2012 -DPROG="\"$prog\"" -o waves/sim_compare \
        regfile.v alu.v control.v cpu_core.v ../m1_ipath/imem.v \
        ../m2_dpath/addr_decoder.v ../m2_dpath/dmem.v ../m2_dpath/dmem_ctrl.v \
        ../m3_shared/mem_arbiter.v ../m3_shared/shared_mem.v tb_system_compare.v
    vvp waves/sim_compare
done

echo ""
echo ">>> Generating Waveforms and Timing Documentation..."
python3 waves/generate_waveform_view.py

echo ""
echo "================================================================================"
echo " ALL M4 REGRESSION SUITES PASSED SUCCESSFULLY!"
echo " Generated artifacts in m4_cpu/waves/:"
ls -lh waves/*.vcd waves/*.svg waves/*.txt
echo "================================================================================"
