#!/usr/bin/env bash
# ==============================================================================
# Project 9: Instruction and Data Memory Hierarchy
# Member 1 (M1) - Instruction Path Automated Test Runner
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p waves

echo "================================================================================"
echo " Running Member 1 (M1) Instruction Path Regression Suite"
echo "================================================================================"

echo ""
echo ">>> [1/3] Compiling and running PC unit testbench (tb_pc.v)..."
iverilog -g2012 -o waves/sim_pc pc.v tb_pc.v
vvp waves/sim_pc

echo ""
echo ">>> [2/3] Compiling and running IMEM unit testbench (tb_imem.v)..."
iverilog -g2012 -o waves/sim_imem imem.v tb_imem.v
vvp waves/sim_imem

echo ""
echo ">>> [3/3] Compiling and running Integrated Instruction Path testbench (tb_ipath.v)..."
iverilog -g2012 -o waves/sim_ipath pc.v imem.v ipath.v tb_ipath.v
vvp waves/sim_ipath

echo ""
echo "================================================================================"
echo " ALL TESTS PASSED! Waveforms generated in m1_ipath/waves/:"
ls -lh waves/*.vcd
echo "================================================================================"
