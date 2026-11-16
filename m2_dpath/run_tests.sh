#!/usr/bin/env bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p waves

echo "Running M2 testbenches..."

echo "1. Testing address decoder..."
iverilog -g2012 -o waves/sim_decoder addr_decoder.v tb_decoder.v
vvp waves/sim_decoder

echo "2. Testing data memory..."
iverilog -g2012 -o waves/sim_dmem dmem.v tb_dmem.v
vvp waves/sim_dmem

echo "3. Testing data memory controller..."
iverilog -g2012 -o waves/sim_dmem_ctrl addr_decoder.v dmem.v dmem_ctrl.v tb_dmem_ctrl.v
vvp waves/sim_dmem_ctrl

# generate waveform views
python3 waves/generate_waveform_view.py

echo "All M2 tests finished successfully."
