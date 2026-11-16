
#!/bin/bash

# M5 - Synthesis script for Harvard and Shared architectures
# Run this script from the main project folder.

set -e

mkdir -p synth/reports

SOURCES="m4_cpu/regfile.v m4_cpu/alu.v m4_cpu/control.v m4_cpu/cpu_core.v m1_ipath/imem.v m1_ipath/imem_top.v m2_dpath/addr_decoder.v m2_dpath/dmem.v m2_dpath/dmem_ctrl.v m3_shared/mem_arbiter.v m3_shared/shared_mem.v top/perf_counters.v top/top_harvard.v top/top_shared.v"

echo "Starting Harvard synthesis..."
yosys -p "read_verilog $SOURCES; hierarchy -top top_harvard; synth -top top_harvard; stat" > synth/reports/harvard_report.txt

echo "Starting Shared Memory synthesis..."
yosys -p "read_verilog $SOURCES; hierarchy -top top_shared; synth -top top_shared; stat" > synth/reports/shared_report.txt

echo "Synthesis reports generated in synth/reports/"
