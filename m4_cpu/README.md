# Project 9: Instruction and Data Memory Hierarchy
## Member 4 (M4) Subsystem: Processor Core & Test Programs

**Course:** Modern Computer Architecture, B.Tech (CS&AI)  
**Assigned Subsystem:** RISC-V Processor Core (`cpu_core.v`, `control.v`, `alu.v`, `regfile.v`, `stub_imem.v`, `stub_dmem.v`), testbenches (`tb_cpu.v`, `tb_stubs.v`, `tb_system_compare.v`), and benchmark programs (`programs/`).

---

### 1. Directory Structure

```text
m4_cpu/
├── cpu_core.v             # Top-level RISC-V processor core (Sections 3.1, 3.2, 3.3)
├── control.v              # Instruction decoder and control signal generator
├── alu.v                  # Arithmetic Logic Unit (ADD, SUB, AND, OR, SLT, PASS_B)
├── regfile.v              # 32 x 32-bit register file (x0 = 0 hardwired)
├── stub_imem.v            # Behavioural instruction memory stub with random stall injection
├── stub_dmem.v            # Behavioural data memory stub with random stall injection
├── tb_cpu.v               # Comprehensive unit testbench (instruction set & handshake)
├── tb_stubs.v             # Automated benchmark runner on behavioural stubs
├── tb_system_compare.v    # Cross-comparison testbench (Harvard vs Shared)
├── run_tests.sh           # One-click test and regression runner script
├── README.md              # Subsystem documentation and architecture description
└── waves/
    ├── generate_waveform_view.py # Waveform and timing visualizer
    ├── m4_pipeline_waveform.svg  # Vector pipeline execution and stall waveform
    ├── m4_timing_table.txt       # Detailed cycle-by-cycle execution log
    ├── tb_cpu.vcd                # VCD waveform dump from unit testbench
    └── tb_stubs.vcd              # VCD waveform dump from stub benchmark execution

programs/
├── assembler.py           # Two-pass RV32I assembler and reference ISS simulator
├── build_programs.py      # Benchmark generator and golden output synthesizer
├── p1_array_sum.asm       # Load-heavy benchmark: sum 16 words from data memory
├── p1_array_sum.hex       # 32-bit instruction machine words
├── p1_array_sum_data.hex  # Initial data memory values (10, 20, ... 160)
├── p1_array_sum_expected.txt # Golden register & memory dump
├── p2_mem_copy.asm        # Memory-intensive benchmark: copy 32 words back-to-back
├── p2_mem_copy.hex
├── p2_mem_copy_data.hex
├── p2_mem_copy_expected.txt
├── p3_alu_only.asm        # Compute-intensive benchmark: ALU chain, zero memory accesses
├── p3_alu_only.hex
├── p3_alu_only_data.hex
├── p3_alu_only_expected.txt
├── p4_max_search.asm      # Search benchmark: conditional branches & loads
├── p4_max_search.hex
├── p4_max_search_data.hex
├── p4_max_search_expected.txt
├── p5_mixed_loop.asm      # Interleaved compute benchmark: arithmetic between loads
├── p5_mixed_loop.hex
├── p5_mixed_loop_data.hex
└── p5_mixed_loop_expected.txt
```

---

### 2. Interface Contract Compliance

The core strictly adheres to the frozen interface contract defined in Sections 3.1, 3.2, and 3.3 of the Project Work Plan:

| Port | Direction | Width | Description | Contract Section |
| :--- | :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock (rising edge active) | Section 3 |
| `rst_n` | Input | 1 | Asynchronous active-low reset | Section 3 |
| `imem_addr` | Output | 32 | Byte address of instruction to fetch (= PC) | Section 3.1 |
| `imem_req` | Output | 1 | CPU wants an instruction this cycle | Section 3.1 |
| `imem_rdata` | Input | 32 | Instruction word (combinational read) | Section 3.1 |
| `imem_ready` | Input | 1 | 1 = `imem_rdata` valid; 0 = CPU stalls & holds PC | Section 3.1 |
| `dmem_addr` | Output | 32 | Byte address of data access | Section 3.2 |
| `dmem_wdata` | Output | 32 | Store data from CPU | Section 3.2 |
| `dmem_re` | Output | 1 | Load request | Section 3.2 |
| `dmem_we` | Output | 1 | Store request | Section 3.2 |
| `dmem_be` | Output | 4 | Byte enables (`4'b1111` for 32-bit word access) | Section 3.2 |
| `dmem_rdata` | Input | 32 | Load data (combinational read) | Section 3.2 |
| `dmem_ready` | Input | 1 | 1 = access completes this cycle; 0 = CPU stalls | Section 3.2 |
| `halt` | Output | 1 | Asserted high when HALT (`32'h0000_006F`) executes | Section 3.3 |

---

### 3. Microarchitecture & Pipeline Design

The processor core utilizes a **2-stage overlapped pipelined architecture (Instruction Fetch | Execute & Writeback)**:

```text
       +-----------------------+                 +-------------------------------+
       |    Stage 1: Fetch     |                 |  Stage 2: Execute & Writeback  |
       +-----------------------+                 +-------------------------------+
                               |
  PC -> imem_addr              |                 ex_instr -> Control Decoder
        imem_req = !halt       |                             Regfile Read
        (wait imem_ready) =====+===> Pipeline ===>           ALU Compute
                               |     Register                Data Memory (LW/SW)
                               |     (ex_instr,              Regfile Writeback
                               |      ex_pc,                 Branch / Jump Redirect
                               |      ex_valid)
```

#### Key Design Highlights:
1. **Zero Data Hazards**:
   Operand registers are read combinationally at the start of the Execute stage, and the result is committed to the register file at the rising clock edge ending that same stage. The subsequent instruction entering Execute reads the updated register file after the edge, completely eliminating the need for complex pipeline forwarding or load-use hazard stalls.
2. **Correct Stall Handshake**:
   - When `dmem_ready == 0` during a load or store, `stall_dmem` freezes both the EX stage and the IF stage. `dmem_addr`, `dmem_wdata`, `dmem_re`, and `dmem_we` are held completely stable, and regfile writeback is inhibited until `dmem_ready == 1`.
   - When `imem_ready == 0` (e.g. during a shared memory bus conflict where data access wins), the fetch stage holds `pc` and `imem_addr` stable, while a bubble (`ex_valid = 0`) enters the Execute stage.
3. **Branch & Jump Handling**:
   - Conditional branches (`BEQ`, `BNE`) evaluate condition in EX. If taken, PC is redirected to `branch_target`, and a 1-cycle bubble is flushed into the pipeline. Not-taken branches incur zero penalty.
   - `JAL` computes `branch_target = ex_pc + imm_j`, writes `ex_pc + 4` to `rd`, redirects PC, and flushes 1 bubble.
4. **Halt Detection**:
   Detects `32'h0000_006F` (`jal x0, 0` self-loop) in the Execute stage, latches `halt = 1`, deasserts `imem_req = 0`, and freezes the core cleanly.

---

### 4. Verification and Benchmark Results

The subsystem was verified across three regression levels using Icarus Verilog (`iverilog` / `vvp`):

#### 4.1 Unit Tests (`tb_cpu.v`)
- **24 / 24 tests passed**:
  - Full RV32I subset: `ADD`, `SUB`, `AND`, `OR`, `ADDI`, `LW`, `SW`, `BEQ`, `BNE`, `JAL`, `LUI`, `HALT`.
  - Signed immediate sign-extension (positive and negative values).
  - Hardwired zero register `x0` (all write attempts ignored).
  - Taken vs not-taken branches for both `BEQ` and `BNE`.
  - Dynamic `dmem_ready` stall injection with signal stability checks.
  - Dynamic `imem_ready` stall injection.
  - Asserting `halt` and deasserting `imem_req`.

#### 4.2 Benchmark Programs on Behavioural Stubs (`tb_stubs.v`)
All 5 programs were run on behavioural stubs both with ideal memory (`STALLS=0`) and with pseudo-random stall injection (`STALLS=1`):

| Program | Category | Instructions Retired | Stalls=0 Cycles (CPI) | Stalls=1 Cycles (CPI) | Functional Status |
| :--- | :--- | :---: | :---: | :---: | :---: |
| `p1_array_sum` | Load-heavy (16 loads, 1 store) | 86 | 102 (1.19) | 135 (1.57) | **PASS** |
| `p2_mem_copy` | Memory-heavy (32 loads, 32 stores) | 197 | 229 (1.16) | 297 (1.51) | **PASS** |
| `p3_alu_only` | Pure ALU (0 loads, 0 stores) | 90 | 105 (1.17) | 138 (1.53) | **PASS** |
| `p4_max_search`| Branch & load (16 loads, 1 store) | 122 | 151 (1.24) | 188 (1.54) | **PASS** |
| `p5_mixed_loop` | Interleaved ALU & loads | 151 | 167 (1.11) | 226 (1.50) | **PASS** |

#### 4.3 Harvard vs Shared Memory System Comparison (`tb_system_compare.v`)
Integrated with Member 1's `imem`, Member 2's `dmem_ctrl`, and Member 3's `shared_mem`:

| Program | Harvard Cycles | Shared Cycles | Memory Conflicts | Cycle Delta | Slowdown |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `p1_array_sum` | 102 | 119 | 17 | +17 | +16.7% |
| `p2_mem_copy` | 229 | 293 | 64 | +64 | +27.9% |
| `p3_alu_only` | 105 | 105 | 0 | 0 | +0.0% |
| `p4_max_search` | 151 | 168 | 17 | +17 | +11.3% |
| `p5_mixed_loop` | 167 | 184 | 17 | +17 | +10.2% |

**Key architectural findings verified:**
- `p3_alu_only`: exactly 0 memory conflicts, proving identical performance between Harvard and Von Neumann architectures on compute workloads.
- `p2_mem_copy`: exactly 64 memory conflicts (matching 32 loads + 32 stores), representing the worst-case structural hazard for shared bus architectures.
- The shared design stall cycles equal the number of memory operations that overlap with instruction fetches, validating the project hypothesis.

---

### 5. Running the Tests

To run the complete automated regression suite:

```bash
cd m4_cpu
./run_tests.sh
```
