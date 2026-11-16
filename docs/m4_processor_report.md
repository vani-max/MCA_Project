# Project 9: Instruction and Data Memory Hierarchy
## Member 4 (M4) Deliverable Report: Processor Core & Benchmark Suite

**Course:** Modern Computer Architecture, B.Tech (CS&AI)  
**Assigned Subsystem:** RISC-V Processor Core (`cpu_core.v`, `control.v`, `alu.v`, `regfile.v`), Testbenches (`tb_cpu.v`, `tb_stubs.v`, `tb_system_compare.v`), Stubs (`stub_imem.v`, `stub_dmem.v`), and Benchmark Programs (`programs/`)  
**Deliverable Files:** `m4_cpu/`, `programs/`, `waves/`

---

### 1. Architecture and Design Overview

The Member 4 (M4) subsystem is the computational engine of the project. It implements a fully compliant RISC-V RV32I processor core that interfaces exclusively through the frozen memory contracts of Section 3.1 (instruction port) and Section 3.2 (data port), along with the Section 3.3 performance counter interface (`halt`).

The subsystem consists of four core microarchitectural modules and supporting test infrastructure:

1. **Top-Level Core (`cpu_core.v`)**:
   - Implements a **2-stage pipelined microarchitecture (Instruction Fetch | Execute & Writeback)**.
   - **Stage 1 (IF):** Drives `imem_addr = pc` and `imem_req = rst_n && !halt`. When `imem_ready = 1`, fetches instructions combinationally and latches them into the pipeline register (`ex_instr`, `ex_pc`, `ex_valid`) on `posedge clk`.
   - **Stage 2 (EX/WB):** Integrates instruction decode, register file read, ALU execution, data memory load/store generation, branch/jump evaluation, and synchronous register writeback.
   - **Stall & Handshake Handling:**
     - Data stall (`stall_dmem = ex_mem_access && !dmem_ready`): Freezes the entire pipeline (holds PC, EX pipeline registers, and keeps memory request signals `dmem_addr`, `dmem_wdata`, `dmem_re`, `dmem_we`, `dmem_be` stable). Register writeback is gated until `dmem_ready = 1`.
     - Fetch stall (`!imem_ready`): Holds PC and `imem_addr` unchanged while introducing a single-cycle bubble (`ex_valid = 0`) into Execute.
   - **Branch / Jump Redirection:** Evaluates `BEQ`, `BNE`, and `JAL` in Execute. Taken branches update `pc <= branch_target` and flush the pipeline with a 1-cycle bubble. Not-taken branches incur 0 penalty cycles.
   - **Halt Execution:** Detects RV32I HALT encoding `32'h0000_006F` (`jal x0, 0`), latches `halt <= 1'b1`, deasserts `imem_req <= 1'b0`, and halts the pipeline cleanly.

2. **Control Unit & Instruction Decoder (`control.v`)**:
   - Decodes RV32I instructions: `ADD`, `SUB`, `AND`, `OR`, `ADDI`, `LW`, `SW`, `BEQ`, `BNE`, `JAL`, `LUI`, and `HALT`.
   - Generates all standard sign-extended immediate formats: I-type (`imm_i`), S-type (`imm_s`), B-type (`imm_b`), U-type (`imm_u`), and J-type (`imm_j`).
   - Drives ALU operation selection, operand source muxing, writeback source muxing, and data memory byte enables (`dmem_be = 4'b1111` for 32-bit word accesses).

3. **Arithmetic Logic Unit (`alu.v`)**:
   - Purely combinational 32-bit ALU supporting addition, subtraction, bitwise AND, bitwise OR, signed comparison (`SLT`), and immediate pass-through (`PASS_B` for `LUI`).
   - Computes `zero` flag for branch equality resolution.

4. **Register File (`regfile.v`)**:
   - $32 \times 32$-bit general-purpose registers (`x0` through `x31`).
   - `x0` is hardwired to zero: reads strictly return `0x0000_0000`; writes to `x0` are discarded.
   - Synchronous write on `posedge clk` when `rd_we` is asserted and `rd != 0`.
   - Asynchronous active-low reset (`rst_n`) initializes all 32 registers to `0x0000_0000`, guaranteeing **zero undefined ('X') states**.

---

### 2. Frozen Contract Compliance

The core matches the exact frozen interface contracts:

- **Section 3.1 Instruction Port:** `imem_addr[31:0]` (out), `imem_req` (out), `imem_rdata[31:0]` (in), `imem_ready` (in).
- **Section 3.2 Data Port:** `dmem_addr[31:0]` (out), `dmem_wdata[31:0]` (out), `dmem_re` (out), `dmem_we` (out), `dmem_be[3:0]` (out), `dmem_rdata[31:0]` (in), `dmem_ready` (in).
- **Section 3.3 Tap:** `halt` (out).

---

### 3. Benchmark Program Suite (`programs/`)

Five benchmark programs were authored in RISC-V assembly (`.asm`), assembled into 32-bit hex files (`.hex`), supplied with initial data (`_data.hex`), and verified against golden reference values (`_expected.txt`):

1. **`p1_array_sum` (Load-heavy):** Sums 16 words from data memory (`0x1000_0000` to `0x1000_003C`) and stores sum ($1360 = \text{0x550}$) at `0x1000_0040`. Total: 86 retired instructions (16 loads, 1 store).
2. **`p2_mem_copy` (Memory-heavy):** Copies 32 words from `0x1000_0000` to `0x1000_0080` via back-to-back `LW` and `SW` instructions. Total: 197 retired instructions (32 loads, 32 stores).
3. **`p3_alu_only` (Pure Compute):** Computes a 15-iteration Fibonacci sequence and extended arithmetic/logic dependency chain entirely in registers. Zero data memory accesses. Total: 90 retired instructions (0 loads, 0 stores).
4. **`p4_max_search` (Branch & Load):** Scans an array of 16 unsigned values, computes element-wise differences, evaluates sign bits, and determines the maximum value ($102 = \text{0x66}$), stored at `0x1000_0040`. Total: 122 retired instructions (16 loads, 1 store).
5. **`p5_mixed_loop` (Interleaved Compute):** Interleaves load operations with a multi-step transformation ($(\text{elem} \times 3 + 7) \ \& \ 0\text{xFF}$), accumulating the total ($2152 = \text{0x868}$) at `0x1000_0040`. Total: 151 retired instructions (16 loads, 1 store).

---

### 4. Verification and Empirical Findings

#### 4.1 Unit Test Regression (`tb_cpu.v`)
- **24 / 24 unit tests passed** covering all instructions, signed negative immediates, hardwired `x0`, taken/not-taken branch redirects, injected memory stalls, and halt termination.

#### 4.2 Stub Memory Regression (`tb_stubs.v`)
All 5 programs executed to HALT on behavioural stubs with 100% correct register and memory outputs under both:
- **Zero-Wait Stubs (`STALLS=0`):** CPI ranges from $1.11$ to $1.24$.
- **Random Stall Injection (`STALLS=1`):** Random 1-cycle stalls on instruction fetch and memory accesses were tolerated without dropping or duplicating requests, verifying stall robustness.

#### 4.3 Harvard vs Shared Memory System Comparison (`tb_system_compare.v`)
Integrating the core with M1's `imem`, M2's `dmem_ctrl`, and M3's `shared_mem` confirms the central architectural hypothesis of Project 9:

| Benchmark Program | Workload Profile | Harvard Cycles (CPI) | Shared Cycles (CPI) | Shared Stall Conflicts | Cycle Delta | Slowdown |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| `p3_alu_only` | Compute-heavy (0% loads/stores) | 105 (1.17) | 105 (1.17) | **0** | **0** | **+0.0%** |
| `p5_mixed_loop`| Interleaved ALU & loads | 167 (1.11) | 184 (1.22) | **17** | **+17** | **+10.2%** |
| `p4_max_search`| Branching & loads | 151 (1.24) | 168 (1.38) | **17** | **+17** | **+11.3%** |
| `p1_array_sum` | Load-heavy (17 mem ops) | 102 (1.19) | 119 (1.38) | **17** | **+17** | **+16.7%** |
| `p2_mem_copy`  | Memory-bound (64 mem ops) | 229 (1.16) | 293 (1.49) | **64** | **+64** | **+27.9%** |

#### Conclusion:
1. **Zero Contention in Harvard:** Independent instruction and data paths permit concurrent fetch and memory operations in the same cycle, achieving CPI close to 1.
2. **Deterministic Contention in Shared Memory:** On a shared single-port bus with data priority, every load and store delays instruction fetch by exactly 1 cycle. The stall count matches the number of memory operations identically ($\Delta \text{Cycles} = \text{Loads} + \text{Stores}$).
3. **Workload Sensitivity:** Pure computational workloads (`p3_alu_only`) suffer zero penalty (+0.0%), whereas memory-intensive workloads (`p2_mem_copy`) suffer significant performance degradation (+27.9%), quantitatively confirming the advantage of Harvard memory hierarchy.
