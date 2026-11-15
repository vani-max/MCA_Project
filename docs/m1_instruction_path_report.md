# Project 9: Instruction and Data Memory Hierarchy
## Member 1 (M1) Deliverable Report: Instruction Path Subsystem
**Course:** Modern Computer Architecture, B.Tech (CS&AI)  
**Assigned Subsystem:** Instruction Path (Program Counter `pc.v` + Instruction Memory `imem.v`)  
**Deliverable Files:** `pc.v`, `imem.v`, `imem_top.v`, `tb_pc.v`, `tb_imem.v`, `tb_ipath.v`, `waves/`

---

### 1. Architecture and Design Overview

The Instruction Path subsystem is responsible for fetching 32-bit RISC-V instructions every clock cycle under the Harvard memory architecture contract. In a Harvard memory organization, instruction fetch operates on an independent bus isolated from data memory accesses, enabling zero contention and single-cycle instruction delivery.

The subsystem consists of two primary hardware components:
1. **Program Counter (`pc.v`)**:
   - Maintains the 32-bit byte address of the instruction being executed/fetched.
   - Operates synchronously on `posedge clk` with an active-low asynchronous reset (`rst_n`).
   - Implements strict priority arbitration:
     $$\text{Reset} > \text{Stall} > \text{Branch Redirect} > \text{Sequential Increment (+4)}$$
   - On `rst_n = 0`, resets the PC register to base address `0x0000_0000`.
   - On `stall = 1`, holds the current PC value unchanged across cycles, freezing execution.
   - On `branch_taken = 1` (with `stall = 0`), loads `branch_target[31:0]` directly into PC.
   - In normal operation (`stall = 0` and `branch_taken = 0`), increments PC by 4 (`pc <= pc + 32'd4`) for word-aligned instruction stepping.

2. **Instruction Memory (`imem.v`)**:
   - Implements a 4 KB memory array organized as $1024 \times 32$-bit words.
   - Pre-initializes all entries to RISC-V `NOP` (`32'h0000_0013`, `addi x0, x0, 0`) to guarantee **zero undefined ('X') values**.
   - Loads program code dynamically via `$readmemh` parameter `MEM_FILE`.
   - **Addressing & Range Checking:**
     - Base address: `0x0000_0000`, Size: 4 KB (`0x0000_0000` to `0x0000_0FFF`).
     - Addresses are byte-addressed; word index is decoded from `addr[11:2]`.
     - Validates address bounds: any access outside `0x0000_0000`–`0x0000_0FFF` (`addr[31:12] != 20'h00000`) is treated as out-of-range and cleanly returns `32'h0000_0013` (NOP) without causing memory faults.
   - **Combinational Read:** Returns instruction word `rdata[31:0]` in the same clock cycle, matching the Harvard contract requirement of `imem_ready = 1`.

---

### 2. Frozen Interface Contract Compliance

| Signal Name | Port Direction | Width | Description / Contract Rule |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 bit | System clock, rising edge active |
| `rst_n` | Input | 1 bit | Active-low asynchronous master reset |
| `stall` | Input | 1 bit | CPU stall request; holds PC and instruction state |
| `branch_taken` | Input | 1 bit | Branch / Jump redirection control |
| `branch_target` | Input | 32 bits | Target byte address for branch / jump |
| `pc` (`imem_addr`)| Output | 32 bits | Current PC output driven to Instruction Memory |
| `rdata` (`imem_rdata`)| Output | 32 bits | Combinational instruction word returned to CPU |
| `imem_ready` | Output | 1 bit | Tied to `1'b1` (always ready in Harvard architecture) |

---

### 3. Verification and Test Results

Three comprehensive testbenches were implemented to guarantee complete coverage and functional independence without requiring the processor core:

1. **PC Unit Testbench (`tb_pc.v`) - 17 / 17 Passed:**
   - Verified reset to `0x0000_0000`.
   - Verified sequential increment (+4 bytes per cycle) across multiple clock steps.
   - Verified branch redirection to `0x0000_0100` and sequential resumption (`0x104`, `0x108`).
   - Verified stall hold across multiple clock cycles (PC stayed strictly constant).
   - Verified **stall + branch priority conflict**: when both `stall = 1` and `branch_taken = 1` are asserted simultaneously, **stall wins** and PC remains locked until stall is released.
   - Verified mid-operation asynchronous reset.

2. **IMEM Unit Testbench (`tb_imem.v`) - 27 / 27 Passed:**
   - Verified initial word read at `0x0000_0000`.
   - Verified all 16 RV32I instructions in `prog_test.hex` loaded via `$readmemh`.
   - Verified pre-initialized NOPs on unwritten words within 4 KB boundary.
   - Verified boundary and out-of-range addresses (`0x0000_1000`, `0x0000_2000`, `0x1000_0000` data memory space, `0xFFFF_FFF0`) all safely return `32'h0000_0013` (NOP).
   - Verified back-to-back rapid combinational read operations without propagation delay issues.
   - Confirmed zero `'X'` or `'Z'` states.

3. **Integrated Instruction Path Testbench (`tb_ipath.v`) - 17 / 17 Passed:**
   - Executed sequential fetch of **10+ instructions** (`0x0000_0000` through `0x0000_0028`).
   - Injected a 2-cycle stall hold at `0x0000_0028`.
   - Performed a branch redirect to `0x0000_0030`, resuming sequential fetch through `HALT` (`0x0000_003C`).
   - Dumped complete waveform to `m1_ipath/waves/ipath_fetch.vcd`.

---

### 4. Waveform Deliverable Summary

The waveform deliverable captured in `waves/ipath_fetch.vcd` (and visual SVG `waves/ipath_fetch_waveform.svg`) demonstrates:
- **Cycles 1–10 (13ns – 96ns):** Normal sequential fetch. PC steps through `0x00`, `0x04`, `0x08`, `0x0C`, `0x10`, `0x14`, `0x18`, `0x1C`, `0x20`, `0x24`, outputting instructions `addi`, `add`, `sub`, `and`, `or`, `lw`, `sw`, `beq`, `bne`.
- **Cycles 11–12 (106ns – 126ns):** `stall = 1` asserted. PC holds steady at `0x0000_0028` and `instr` holds `0x00C000EF` (`jal x1`) without state drift.
- **Cycle 13 (146ns):** Stall deasserts and `branch_taken = 1` with `branch_target = 0x0000_0030`. PC immediately vectors to `0x0000_0030` (`addi x1, x0, 1`).
- **Cycles 14–16 (156ns – 176ns):** Sequential fetch resumes to `0x34`, `0x38`, and reaches `0x3C` (`HALT`).

---

### 5. Demo Script for Presentation (Member 1 - 1 Minute)

> *"Hello everyone. I am Member 1, responsible for the Instruction Path subsystem comprising the Program Counter (`pc.v`) and the Instruction Memory (`imem.v`).*  
> *Under our Harvard architecture, instruction memory has a dedicated bus, providing zero-latency combinational reads with `imem_ready` permanently tied high.*  
> *Here in our waveform `ipath_fetch.vcd`, you can observe three critical behaviors:*  
> *First, starting at reset `0x0000_0000`, the PC sequentially fetches 10 instructions, advancing by 4 bytes each cycle.*  
> *Second, when the pipeline injects a stall, the PC holds its state for two full clock cycles without corruption, and our priority logic ensures stall wins even if a branch is simultaneously requested.*  
> *Third, upon branch redirection to `0x0000_0030`, the PC immediately vectors to the target instruction and cleanly resumes execution down to `HALT`.*  
> *All unit tests passed with zero X values, and our module interface strictly matches the Phase 3 integration contract."*
