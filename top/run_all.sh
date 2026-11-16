
#!/bin/bash

# ============================================================
# Project 9 - M5 Automated Regression Runner
# Runs all five benchmark programs on Harvard and Shared memory
# ============================================================

set -e

# Move to repository root
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p top/logs

echo "=============================================="
echo " M5: MEMORY HIERARCHY REGRESSION TEST"
echo "=============================================="

# Check simulator availability
if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: Icarus Verilog (iverilog) is not installed."
    exit 1
fi

if ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: vvp is not installed."
    exit 1
fi

# Required source files
SOURCES=(
    m4_cpu/regfile.v
    m4_cpu/alu.v
    m4_cpu/control.v
    m4_cpu/cpu_core.v
    m1_ipath/imem.v
    m1_ipath/imem_top.v
    m2_dpath/addr_decoder.v
    m2_dpath/dmem.v
    m2_dpath/dmem_ctrl.v
    m3_shared/mem_arbiter.v
    m3_shared/shared_mem.v
    top/perf_counters.v
    top/top_harvard.v
    top/top_shared.v
    top/tb_system.v
)

PROGRAMS=(
    p1_array_sum
    p2_mem_copy
    p3_alu_only
    p4_max_search
    p5_mixed_loop
)

# Verify source files
for source in "${SOURCES[@]}"; do
    if [ ! -f "$source" ]; then
        echo "ERROR: Missing source file: $source"
        exit 1
    fi
done

echo ""
echo "Compiling M5 testbench..."

iverilog -g2012 \
    -s tb_system \
    -o top/sim_m5 \
    "${SOURCES[@]}"

echo "Compilation successful."

# Run each benchmark
for prog in "${PROGRAMS[@]}"; do

    echo ""
    echo "----------------------------------------------"
    echo "Running benchmark: $prog"
    echo "----------------------------------------------"

    PROGRAM_FILE="programs/${prog}.hex"
    DATA_FILE="programs/${prog}_data.hex"
    LOG_FILE="top/logs/${prog}.log"

    if [ ! -f "$PROGRAM_FILE" ]; then
        echo "ERROR: Missing program: $PROGRAM_FILE"
        exit 1
    fi

    if [ -f "$DATA_FILE" ]; then
        vvp top/sim_m5 \
            +PROGRAM="$PROGRAM_FILE" \
            +DATA="$DATA_FILE" | tee "$LOG_FILE"
    else
        vvp top/sim_m5 \
            +PROGRAM="$PROGRAM_FILE" | tee "$LOG_FILE"
    fi

    if grep -q "\[FAIL\]" "$LOG_FILE"; then
        echo "RESULT: FAIL - $prog"
        exit 1
    fi

    if ! grep -q "\[PASS\]" "$LOG_FILE"; then
        echo "RESULT: INCOMPLETE - $prog"
        exit 1
    fi

    echo "RESULT: PASS - $prog"

done

echo ""
echo "=============================================="
echo " ALL FIVE BENCHMARKS COMPLETED"
echo " Logs saved in top/logs/"
echo "=============================================="
