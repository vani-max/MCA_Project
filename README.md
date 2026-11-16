# Modern Computer Architecture: Instruction and Data Memory Hierarchy

**Course:** Modern Computer Architecture, B.Tech (CS&AI)  
**Project:** Project 9 — Harvard vs. Von Neumann (Shared Memory) Architecture Comparison  
**Repository:** [https://github.com/vani-max/MCA_Project](https://github.com/vani-max/MCA_Project)  
**Implementation Status:** All 5 Subsystems Verified & Integrated (`v1_m1`)

---

## 1. Project Overview

This project implements, evaluates, and empirically compares two fundamental computer architecture memory organizations in synthesizable Verilog:
1. **Harvard Memory Architecture (`top_harvard.v`):** Separate instruction and data memories with dedicated buses, allowing simultaneous instruction fetch and memory read/write in a single clock cycle without structural hazards.
2. **Von Neumann Shared Memory Architecture (`top_shared.v`):** A unified single-port memory array where instruction fetch and data memory access contend for the shared memory port through a hardware arbiter. Structural hazards force one-cycle stalls on instruction fetch whenever simultaneous accesses occur.

---

## 2. 5-Member Team Responsibility Matrix

Every member developed their module against a **frozen interface contract** using behavioral stubs and dedicated unit testbenches, ensuring independent development and zero merge conflicts.

| Member | Subsystem Owned | Key Verilog Modules | Responsibility & Deliverables | Status |
| :---: | :--- | :--- | :--- | :---: |
| **M1 - Vani Vashishtha** | **Instruction Path** | `pc.v`, `imem.v`, `imem_top.v`, `ipath.v` | PC with priority logic, 4 KB combinational instruction memory, NOP padding, fetch waveforms | **100% Passed** |
| **M2 - Bhoomi Chhikara** | **Data Path** | `dmem.v`, `addr_decoder.v`, `dmem_ctrl.v` | 4 KB data RAM, 4-bit byte enables, address decoder, sticky fault latching | **100% Passed** |
| **M3 - Ankita Thakur** | **Shared Memory & Arbiter** | `shared_mem.v`, `mem_arbiter.v` | Unified 8 KB single-port memory, data-priority arbiter, hardware conflict counter, density sweep | **100% Passed** |
| **M4-Vidit Sachan** | **Processor Core & Programs** | `cpu_core.v`, `alu.v`, `regfile.v`, `control.v` | Single-cycle RV32I core with stall control, HALT detection, 5 assembly benchmark programs | **100% Passed** |
| **M5-Farhana Pervin** | **System Integration & Metrics** | `top_harvard.v`, `top_shared.v`, `perf_counters.v` | Top wrappers, golden Python ISS (`iss.py`), automated regression runner (`run_all.sh`) | **100% Passed** |

---

## 3. Frozen Interface Contract & Memory Map

All signals are active-high. All modules use system clock `clk` and active-low master reset `rst_n`. All instruction and data words are 32-bit.

### 3.1 Memory Map

| Region | Base Address | Size | Used By |
| :--- | :---: | :---: | :--- |
| **Instruction Memory** | `0x0000_0000` | 4 KB (1024 words) | Harvard I-side; Shared memory lower half |
| **Data Memory** | `0x1000_0000` | 4 KB (1024 words) | Harvard D-side; Shared memory upper half |

- Addresses outside these mapped windows return safe defaults (`32'h0000_0013` NOP on instruction port; `0` and sticky `access_fault` on data port).

### 3.2 CPU Instruction Port (CPU → Instruction Memory)

| Signal | Dir (from CPU) | Width | Description / Contract Rule |
| :--- | :---: | :---: | :--- |
| `imem_addr` | Output | 32 | Byte address of instruction to fetch (= PC) |
| `imem_req` | Output | 1 | CPU requests instruction fetch this cycle |
| `imem_rdata` | Input | 32 | Instruction word, combinational read, valid when `imem_ready = 1` |
| `imem_ready` | Input | 1 | Handshake flag: `1` = valid data; `0` = CPU must hold PC and stall |

*Contract rule:* In Harvard architecture, `imem_ready` is permanently `1'b1`. In shared architecture, `imem_ready` drops to `0` whenever a data access collides.

### 3.3 CPU Data Port (CPU → Data Memory)

| Signal | Dir (from CPU) | Width | Description / Contract Rule |
| :--- | :---: | :---: | :--- |
| `dmem_addr` | Output | 32 | Byte address of data access |
| `dmem_wdata` | Output | 32 | Store data |
| `dmem_re` | Output | 1 | Load request |
| `dmem_we` | Output | 1 | Store request |
| `dmem_be` | Output | 4 | Byte enables (`4'b1111` for 32-bit word, `4'b0011` for halfword, `4'b0001` for byte) |
| `dmem_rdata` | Input | 32 | Load data, combinational read, valid when `dmem_ready = 1` |
| `dmem_ready` | Input | 1 | Handshake flag: `1` = access completes this cycle; `0` = CPU must stall |

*Write rule:* A store takes effect at `posedge clk` only when `dmem_we && dmem_ready`. Data access always wins arbitration over instruction fetch.

---

## 4. Subsystem Details & Implementations

### Member 1: Instruction Path Subsystem (`m1_ipath/`)
- **Program Counter (`pc.v`):** 32-bit PC register with asynchronous active-low reset (`rst_n`) to `0x0000_0000`. Increments by 4 each cycle. Loads `branch_target` when `branch_taken = 1`. Freezes state when `stall = 1`.
  - **Priority Rule:** $$\text{Reset} > \text{Stall} > \text{Branch Redirect} > \text{Sequential Increment (+4)}$$
  - *Stall strictly wins over branch requests.*
- **Instruction Memory (`imem.v`):** 4 KB ($1024 \times 32$-bit) memory array. Pre-initialized in an `initial` block with RISC-V `NOP` (`32'h0000_0013`) to guarantee **zero `'X'` values**. Word indexing via `addr[11:2]`. Out-of-range addresses cleanly return `NOP`.
- **Contract Wrapper (`imem_top.v`):** Directly exposes Section 3.1 contract ports (`imem_addr`, `imem_req`, `imem_rdata`, `imem_ready = 1'b1`).
- **Integrated Subsystem (`ipath.v`):** Glues `pc.v` and `imem.v` for standalone fetch path simulation.

### Member 2: Data Path Subsystem (`m2_dpath/`)
- **Data Memory Core (`dmem.v`):** $1024 \times 32$-bit synchronous write, combinational read RAM with individual byte-write lanes.
- **Address Decoder (`addr_decoder.v`):** Validates address within `0x1000_0000`–`0x1000_0FFF` and extracts word index `addr[11:2]`.
- **Data Controller (`dmem_ctrl.v`):** Wraps memory and decoder behind Section 3.2 CPU interface. Drives `dmem_ready = 1'b1` for zero-wait-state Harvard access, implements read-modify-write for byte and halfword stores, returns 0 and asserts sticky `access_fault` on invalid access.

### Member 3: Shared-Memory Arbiter Subsystem (`m3_shared/`)
- **Single-Port Memory Core (`shared_mem.v`):** Single unified 8 KB ($2048 \times 32$-bit) memory array containing instruction space (`0x0000_0xxx`, lower 1024 words) and data space (`0x1000_0xxx`, upper 1024 words).
- **Arbiter (`mem_arbiter.v`):** Multiplexes the single physical port between instruction and data requests.
  - **Arbitration Policy:** Data access has absolute priority over instruction fetch (`grant_data = dmem_re | dmem_we`).
  - **Conflict Handling:** When both ports request in the same cycle, `imem_ready` drops to `0` (CPU stalls PC for 1 cycle), while `dmem_ready = 1` (data is served immediately).
  - Exposes hardware output `conflict_count` to measure dynamic structural stalls.

### Member 4: RV32I Processor Core & Benchmarks (`m4_cpu/`, `programs/`)
- **Processor Core (`cpu_core.v`):** Single-cycle RISC-V RV32I datapath featuring a 32-register register file (`x0` hardwired to 0), arithmetic-logic unit (`alu.v`), control logic (`control.v`), and immediate generator.
- **Synchronous Stall Logic:** Whenever `imem_ready = 0` or `dmem_ready = 0`, the core freezes PC and pipeline registers while maintaining stable bus requests.
- **HALT Instruction:** Decodes `32'h0000_006F` (`jal x0, 0` self-loop) into `halt = 1`.
- **5 Benchmark Programs:**
  1. `p1_array_sum`: Sums 16 words from data memory (load-heavy).
  2. `p2_mem_copy`: Copies 32 words to another region (loads and stores back-to-back, worst-case shared memory conflicts).
  3. `p3_alu_only`: Pure ALU operations without memory access (best-case for shared memory, zero stalls).
  4. `p4_max_search`: Finds maximum value in an array (branches and loads).
  5. `p5_mixed_loop`: Loops with interleaved ALU computations and memory operations.

### Member 5: Top Wrappers, Golden ISS & Performance Metrics (`top/`, `golden/`)
- **`top_harvard.v`:** Integrates CPU core + M1 `imem` + M2 `dmem_ctrl` + performance counters.
- **`top_shared.v`:** Integrates CPU core + M3 `shared_mem` + performance counters.
- **Performance Counters (`perf_counters.v`):** Non-intrusive hardware monitors tracking total execution cycles, instructions retired, stall cycles, load count, and store count.
- **Golden Model (`golden/iss.py`):** Independent Python instruction set simulator used for automated validation of final register files and memory contents.

---

## 5. Comparative Evaluation & Benchmark Results

All five benchmarks were executed across both memory architectures using `top/run_all.sh`. Register files and memory dumps matched the golden model with 100% accuracy.

| Benchmark Program | Harvard Cycles | Shared Cycles | Structural Stalls | Harvard CPI | Shared CPI | Slowdown (%) | Key Architectural Observation |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`p1_array_sum`** | 102 | 119 | 17 | 1.00 | 1.17 | +16.7% | 16 loads + 1 store cause 17 fetch stalls on unified bus |
| **`p2_mem_copy`** | 229 | 293 | 64 | 1.00 | 1.28 | +27.9% | **Worst-case bottleneck:** Back-to-back loads and stores |
| **`p3_alu_only`** | 53 | 53 | 0 | 1.00 | 1.00 | **0.0%** | **Best-case:** Zero data accesses yields identical performance |
| **`p4_max_search`** | 151 | 168 | 17 | 1.00 | 1.11 | +11.3% | Data loads overlap with branch execution |
| **`p5_mixed_loop`** | 167 | 184 | 17 | 1.00 | 1.10 | +10.2% | ALU instructions between memory accesses amortize stalls |

### Structural Hazard Scaling (M3 Density Sweep)
Simulation of 100 instructions under variable memory access densities confirms that shared memory stall cycles scale in direct proportion to load/store frequency:
- **0% Data Density:** 0 conflicts $\rightarrow$ CPI = 1.01 (0% slowdown)
- **50% Data Density:** 50 conflicts $\rightarrow$ CPI = 1.51 (49% slowdown)
- **100% Data Density:** 99 conflicts $\rightarrow$ CPI = 2.00 (98% slowdown)

---

## 6. How to Run the Tests

### Prerequisites
- [Icarus Verilog](https://steveicarus.github.io/iverilog/) (`iverilog`, `vvp`)
- Python 3

### 6.1 Run Full System Regression (Harvard vs. Shared on all 5 Benchmarks)
```bash
cd ~/Desktop/MCA_Project
bash top/run_all.sh
```

### 6.2 Run Member 1 (Instruction Path) Tests
```bash
cd ~/Desktop/MCA_Project/m1_ipath
./run_tests.sh
```
*Executes `tb_pc.v` (17 tests), `tb_imem.v` (27 tests), and `tb_ipath.v` (17 tests). Generates `waves/ipath_fetch.vcd` and `waves/ipath_fetch_waveform.svg`.*

### 6.3 Run Member 2 (Data Path) Tests
```bash
cd ~/Desktop/MCA_Project/m2_dpath
./run_tests.sh
```
*Executes `tb_decoder.v`, `tb_dmem.v`, and `tb_dmem_ctrl.v` (52 tests).*

### 6.4 Run Member 3 (Shared Memory & Arbiter) Tests
```bash
cd ~/Desktop/MCA_Project/m3_shared
./run_tests.sh
```
*Executes `tb_arbiter.v` (34 tests), `tb_shared_mem.v` (75 tests), and `tb_density.v` (10 tests). Generates `density_sweep.csv`.*

### 6.5 Run Member 4 (CPU Core) Tests
```bash
cd ~/Desktop/MCA_Project/m4_cpu
./run_tests.sh
```
*Executes `tb_stubs.v`, `tb_cpu.v`, and all 5 benchmark programs against behavioral stubs.*

### 6.6 Run Golden Model (Python ISS)
```bash
python3 golden/iss.py --program programs/p1_array_sum.hex --data programs/p1_array_sum_data.hex
```

---

## 7. Prototype Video Demonstration Guide

The team demonstration is structured as a 4-minute 40-second video presentation where all five members present their respective modules:

| Segment | Timestamp | Speaker | Subsystem | Key Screen Visuals |
| :---: | :---: | :--- | :--- | :--- |
| **1** | `0:00 – 0:40` | **Member 5** | Team Intro & Project Concept | System architecture block diagram + GitHub repository overview |
| **2** | `0:40 – 1:30` | **Member 1** | Instruction Path (`m1_ipath`) | `pc.v` priority logic, `imem.v` NOP pre-fill, `./run_tests.sh`, fetch waveform SVG |
| **3** | `1:30 – 2:20` | **Member 2** | Data Path (`m2_dpath`) | `addr_decoder.v`, `dmem_ctrl.v` ready & sticky fault, 52 unit tests, waveform |
| **4** | `2:20 – 3:10` | **Member 3** | Shared Memory (`m3_shared`) | `mem_arbiter.v` priority logic, unified 8 KB core, collision waveform, density sweep |
| **5** | `3:10 – 3:55` | **Member 4** | CPU Core (`m4_cpu`) | `cpu_core.v` stall logic, ALU, 5 benchmark assembly files, behavioral stubs |
| **6** | `3:55 – 4:40` | **Member 5** | Integration & Wrap-Up | `top_harvard.v`, `golden/iss.py` validation, performance counters, results table |

*Detailed, second-by-second video cue sheets with word-for-word scripts are located in:*
- Member 1 Guide: `docs/m1_instruction_path_report.md`
- Member 3 Guide: `m3_shared/m3_report.md`

---

## 8. Repository Layout

```
MCA_Project/
├── README.md                             # Master project documentation
├── .gitignore                            # Simulation binaries and build ignore rules
├── docs/                                 # Architecture diagrams and member reports
│   ├── block_diagrams.md                 # System diagrams for Harvard and Shared designs
│   ├── m1_instruction_path_report.md     # Member 1 technical report & video script
│   ├── m4_processor_report.md            # Member 4 CPU core report
│   └── m5_architecture.md                # System integration and memory contract spec
├── golden/                               # Reference model
│   └── iss.py                            # Golden Python RV32I Instruction Set Simulator
├── m1_ipath/                             # Member 1: Instruction Path Subsystem
│   ├── pc.v                              # 32-bit Program Counter
│   ├── imem.v                            # 4 KB Instruction Memory (combinational)
│   ├── imem_top.v                        # Section 3.1 contract wrapper
│   ├── ipath.v                           # Integrated fetch path module
│   ├── prog_test.hex                     # 16-word RV32I test hex
│   ├── tb_pc.v                           # PC unit testbench (17 tests)
│   ├── tb_imem.v                         # IMEM unit testbench (27 tests)
│   ├── tb_ipath.v                        # Waveform deliverable testbench (17 tests)
│   ├── run_tests.sh                      # M1 automated test runner
│   └── waves/                            # VCDs, SVG waveform, and timing table
├── m2_dpath/                             # Member 2: Data Path Subsystem
│   ├── dmem.v                            # 4 KB Data RAM with byte enables
│   ├── addr_decoder.v                    # Address decoder (0x1000_0000 range)
│   ├── dmem_ctrl.v                       # R/W Controller with sticky fault
│   ├── tb_*.v                            # Unit testbenches (52 tests)
│   ├── run_tests.sh                      # M2 automated test runner
│   └── waves/                            # VCD and SVG waveforms
├── m3_shared/                            # Member 3: Shared Memory Arbiter Subsystem
│   ├── shared_mem.v                      # Unified 8 KB single-port memory
│   ├── mem_arbiter.v                     # Data-priority arbiter
│   ├── tb_arbiter.v                      # Arbiter unit testbench (34 tests)
│   ├── tb_shared_mem.v                   # System testbench (75 tests)
│   ├── tb_density.v                      # Density sweep testbench (10 tests)
│   ├── run_tests.sh                      # M3 automated test runner
│   └── waves/                            # Waveforms and density_sweep.csv
├── m4_cpu/                               # Member 4: RV32I Processor Core
│   ├── cpu_core.v                        # RV32I datapath with stall control
│   ├── alu.v                             # 32-bit ALU
│   ├── regfile.v                         # 32 x 32-bit Register File
│   ├── control.v                         # Main and ALU control unit
│   ├── stub_imem.v                       # Behavioral instruction memory stub
│   ├── stub_dmem.v                       # Behavioral data memory stub
│   ├── tb_cpu.v                          # CPU core testbench
│   └── run_tests.sh                      # M4 automated test runner
├── programs/                             # 5 RV32I Benchmark Programs
│   ├── p1_array_sum.*                    # Sum 16 words (.asm, .hex, _expected.txt)
│   ├── p2_mem_copy.*                     # Copy 32 words (.asm, .hex, _expected.txt)
│   ├── p3_alu_only.*                     # ALU computation chain (.asm, .hex, _expected.txt)
│   ├── p4_max_search.*                   # Array maximum search (.asm, .hex, _expected.txt)
│   └── p5_mixed_loop.*                   # Interleaved loop (.asm, .hex, _expected.txt)
├── synth/                                # Synthesis scripts and area reports
└── top/                                  # Member 5: Top-Level Integration
    ├── top_harvard.v                     # Harvard top-level system wrapper
    ├── top_shared.v                      # Shared-memory top-level system wrapper
    ├── perf_counters.v                   # Hardware performance counters
    ├── tb_system.v                       # System verification testbench
    └── run_all.sh                        # Master regression runner across all 5 benchmarks
```

---

## 9. Conclusion

The empirical findings from Project 9 demonstrate the classic memory hierarchy trade-off:
- **Harvard Architecture** provides predictable single-cycle instruction throughput (CPI = 1.00) by eliminating structural bus hazards, making it ideal for high-performance processors and DSPs at the expense of separate bus wiring and partitioned memory capacity.
- **Von Neumann Architecture** offers unified storage flexibility and reduced pin count, but suffers quantifiable cycle penalties that scale directly with data memory activity—incurring up to a **27.9% execution slowdown** on memory-intensive algorithms like array copy.
