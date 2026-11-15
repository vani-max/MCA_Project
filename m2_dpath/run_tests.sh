#!/usr/bin/env bash
# ==============================================================================
# Project 9: Instruction and Data Memory Hierarchy
# Member 2 (M2) - Data Path Automated Regression Test Runner
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p waves

echo "================================================================================"
echo " Running Member 2 (M2) Data Path Regression Suite"
echo "================================================================================"

echo ""
echo ">>> [1/3] Compiling and running Address Decoder unit testbench (tb_decoder.v)..."
iverilog -g2012 -o waves/sim_decoder addr_decoder.v tb_decoder.v
vvp waves/sim_decoder

echo ""
echo ">>> [2/3] Compiling and running Data Memory Core unit testbench (tb_dmem.v)..."
iverilog -g2012 -o waves/sim_dmem dmem.v tb_dmem.v
vvp waves/sim_dmem

echo ""
echo ">>> [3/3] Compiling and running Data Memory Controller testbench (tb_dmem_ctrl.v)..."
iverilog -g2012 -o waves/sim_dmem_ctrl addr_decoder.v dmem.v dmem_ctrl.v tb_dmem_ctrl.v
vvp waves/sim_dmem_ctrl

echo ""
echo ">>> [Post-Process] Generating visual SVG waveform and cycle timing table..."
python3 waves/generate_waveform_view.py

echo ""
echo "================================================================================"
echo " ALL TESTS PASSED! Deliverables generated in m2_dpath/waves/:"
echo "--------------------------------------------------------------------------------"
ls -lh waves/*.vcd waves/*.svg waves/*.txt
echo "================================================================================"
