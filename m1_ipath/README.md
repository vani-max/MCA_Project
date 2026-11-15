# Member 1 (M1) — Instruction Path Subsystem
**Project 9:** Instruction and Data Memory Hierarchy (Harvard vs Shared)  
**Assigned Modules:** Program Counter (`pc.v`) + Instruction Memory (`imem.v`)

---

## 1. Directory Structure

```
m1_ipath/
├── pc.v                            # Program Counter module
├── imem.v                          # Instruction Memory (4 KB, 1024 words)
├── imem_top.v                      # Contract wrapper for Section 3.1 signals
├── ipath.v                         # Integrated Instruction Path (PC + IMEM)
├── prog_test.hex                   # 16-word hand-assembled RV32I test program + NOPs
├── tb_pc.v                         # Unit testbench for Program Counter
├── tb_imem.v                       # Unit testbench for Instruction Memory
├── tb_ipath.v                      # Deliverable testbench (10+ fetches + stall + branch)
├── run_tests.sh                    # Automated regression shell script
└── waves/                          # Waveform deliverables and logs
    ├── tb_pc.vcd                   # PC testbench VCD
    ├── tb_imem.vcd                 # IMEM testbench VCD
    ├── ipath_fetch.vcd             # Waveform deliverable VCD
    ├── ipath_fetch_waveform.svg    # Visual SVG timing diagram
    ├── ipath_timing_table.txt      # Text cycle-by-cycle timing log
    └── generate_waveform_view.py   # Waveform exporter utility
```

---

## 2. Quick Start: Running All Tests

To run the full suite of unit tests and generate all waveforms, run:

```bash
chmod +x run_tests.sh
./run_tests.sh
```

Or run individual simulations with Icarus Verilog:

```bash
# 1. Program Counter Unit Tests:
iverilog -g2012 -o waves/sim_pc pc.v tb_pc.v && vvp waves/sim_pc

# 2. Instruction Memory Unit Tests:
iverilog -g2012 -o waves/sim_imem imem.v tb_imem.v && vvp waves/sim_imem

# 3. Integrated Instruction Path & Waveform Deliverable:
iverilog -g2012 -o waves/sim_ipath pc.v imem.v ipath.v tb_ipath.v && vvp waves/sim_ipath
```

To view waveforms in GTKWave:
```bash
gtkwave waves/ipath_fetch.vcd
```
Or view the rendered SVG directly in any browser:
```bash
open waves/ipath_fetch_waveform.svg
```

---

## 3. Module Specifications & Contract Compliance

### `pc.v` (Program Counter)
- **Ports:**
  - `clk` (input, 1 bit): Master clock (rising edge active)
  - `rst_n` (input, 1 bit): Master reset (active-low asynchronous)
  - `stall` (input, 1 bit): Active-high stall signal
  - `branch_taken` (input, 1 bit): Active-high branch/jump redirect flag
  - `branch_target` (input, 32 bit): Target byte address
  - `pc` (output, 32 bit): Current instruction address
- **Priority Logic:**
  `!rst_n` (Reset to 0x0000_0000) > `stall` (Hold PC) > `branch_taken` (Load Target) > Default (`pc + 4`).
  *Stall strictly wins over branch requests.*

### `imem.v` (Instruction Memory)
- **Parameters:**
  - `MEM_FILE`: Path to 32-bit hex file loaded with `$readmemh` (default `""`)
  - `DEPTH`: Number of words (default `1024` = 4 KB)
- **Ports:**
  - `addr` (input, 32 bit): Byte address from CPU/PC
  - `rdata` (output, 32 bit): Instruction word (combinational read)
- **Addressing & Behavior:**
  - Memory map: `0x0000_0000` to `0x0000_0FFF` (4 KB).
  - Word index: `addr[11:2]`.
  - Out-of-range addresses (`addr[31:12] != 20'h00000`) cleanly return `32'h0000_0013` (NOP).
  - Pre-initialized to NOPs: eliminates all undefined `'X'` states.

### `imem_top.v` (Integration Wrapper)
- Exposes exact Section 3.1 contract ports:
  `imem_addr`, `imem_req`, `imem_rdata`, `imem_ready` (tied to `1'b1`).
- Allows M5 to directly instantiate `imem_top` without manual signal mapping.

---

## 4. Test Summary

| Testbench | Focus Areas | Total Tests | Status |
| :--- | :--- | :---: | :---: |
| `tb_pc.v` | Reset, +4 sequential increment, branch redirection, stall hold, stall+branch priority (stall wins), mid-run reset | 17 | **17 / 17 PASSED** |
| `tb_imem.v` | First/last word, loaded hex instructions, pre-init NOPs, boundary out-of-range, high out-of-range, back-to-back reads | 27 | **27 / 27 PASSED** |
| `tb_ipath.v` | Deliverable: 10+ sequential fetches, 2-cycle stall hold, branch redirection, sequential resumption to HALT | 17 | **17 / 17 PASSED** |

**Zero `'X'` values detected across all simulations.**
