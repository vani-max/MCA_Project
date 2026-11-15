# Member 2 (M2) — Data Path Subsystem
**Project 9:** Instruction and Data Memory Hierarchy (Harvard vs Shared)  
**Assigned Modules:** Data Memory (`dmem.v`) + Address Decoder (`addr_decoder.v`) + R/W Control (`dmem_ctrl.v`)

---

## 1. Directory Structure

```
m2_dpath/
├── addr_decoder.v                  # Address decoding & validation logic
├── dmem.v                          # 1024 x 32-bit RAM with byte enables
├── dmem_ctrl.v                     # Section 3.2 CPU Data Port contract controller
├── tb_decoder.v                    # Unit testbench for Address Decoder
├── tb_dmem.v                       # Unit testbench for Data Memory Core
├── tb_dmem_ctrl.v                  # Unit testbench for Data Memory Controller
├── run_tests.sh                    # Automated regression test runner
├── README.md                       # Subsystem documentation & report section
└── waves/                          # Waveform deliverables and simulation traces
    ├── tb_decoder.vcd              # Address Decoder VCD dump
    ├── tb_dmem.vcd                 # Data Memory Core VCD dump
    ├── tb_dmem_ctrl.vcd            # Deliverable VCD (Write/Read + Out-of-Range)
    ├── dmem_waveform.svg           # Scalable vector graphics waveform diagram
    ├── dmem_timing_table.txt       # Cycle-by-cycle signal transition table
    └── generate_waveform_view.py   # Automated waveform parser & visual generator
```

---

## 2. Quick Start: Running Tests & Generating Waveforms

To run the complete automated regression suite:

```bash
cd m2_dpath
chmod +x run_tests.sh
./run_tests.sh
```

Or run individual simulations using Icarus Verilog (`iverilog`):

```bash
# 1. Address Decoder Unit Tests:
iverilog -g2012 -o waves/sim_decoder addr_decoder.v tb_decoder.v && vvp waves/sim_decoder

# 2. Data Memory Core Unit Tests:
iverilog -g2012 -o waves/sim_dmem dmem.v tb_dmem.v && vvp waves/sim_dmem

# 3. Data Memory Controller Specification Tests:
iverilog -g2012 -o waves/sim_dmem_ctrl addr_decoder.v dmem.v dmem_ctrl.v tb_dmem_ctrl.v && vvp waves/sim_dmem_ctrl
```

Waveforms can be inspected with GTKWave or directly in any web browser:
```bash
# Interactive GTKWave inspection
gtkwave waves/tb_dmem_ctrl.vcd

# Or open the vector waveform directly
open waves/dmem_waveform.svg
```

---

## 3. Subsystem Architecture & Report Description

### 3.1 Overview
The **Data Path Subsystem (`m2_dpath`)** provides the primary read/write storage interface for the Harvard architecture processor. It connects directly to the CPU's memory stage and satisfies the frozen **Section 3.2 CPU Data Port Contract**. It provides single-cycle zero-wait-state accesses (`dmem_ready = 1`), flexible sub-word granularity through byte enables (`dmem_be[3:0]`), and hardware protection against out-of-bounds memory accesses.

```
       +-------------------------------------------------------------+
       |                         dmem_ctrl.v                         |
       |                                                             |
CPU -->| dmem_addr[31:0] ───► +--------------------+                 |
CPU -->| dmem_re, dmem_we ──► |   addr_decoder.v   |──► word_index   |
       |                      |                    |──► addr_error ──┼──► access_fault
       |                      +--------------------+                 |    (sticky)
       |                                │                            |
       |                                ▼                            |
CPU -->| dmem_wdata[31:0] ──► +--------------------+                 |
CPU -->| dmem_be[3:0]    ───► |       dmem.v       |                 |
CPU <--| dmem_rdata[31:0] ◄───| (1024x32-bit RAM)  |                 |
CPU <--| dmem_ready = 1  ◄─── +--------------------+                 |
       +-------------------------------------------------------------+
```

### 3.2 Address Decoder (`addr_decoder.v`)
* **Address Range:** Base `0x1000_0000` to `0x1000_0FFF` (4 KB, 1024 32-bit words).
* **Word Indexing:** Word index `word_index[9:0] = addr[11:2]` maps each 4-byte segment to one memory location (`0` to `1023`).
* **Region Detection:**
  * `sel_dmem`: Asserted high when `0x1000_0000 <= addr < 0x1000_1000`.
  * `sel_imem_region`: Asserted high when `0x0000_0000 <= addr < 0x0000_1000` (reserved for cross-checking in shared memory mode).
  * `addr_error`: Asserted high whenever the requested address falls outside the allocated 4 KB data memory range (`!sel_dmem`).

### 3.3 Data Memory Core (`dmem.v`)
* **Array Dimension:** $1024 \times 32$-bit storage array (`reg [31:0] mem [0:1023]`).
* **Synchronous Store:** Writes occur on `posedge clk` gated by `we`.
* **Combinational Read:** Read access is combinational (`assign rdata = mem[addr];`), delivering loaded data in the same cycle without latency bubbles.
* **Pre-Initialization:** Pre-initialized to `32'h0000_0000` across all 1024 entries, ensuring zero unknown (`'X'`) states during initial simulation or reset.

### 3.4 R/W Control & Contract Compliance (`dmem_ctrl.v`)
The controller wraps `addr_decoder` and `dmem` behind the frozen CPU data port:
1. **Zero-Wait Handshake (`dmem_ready = 1`):** In the Harvard configuration, data memory operates with dedicated bandwidth and never stalls the processor; `dmem_ready` is hardwired high.
2. **Byte-Enable Masking & Read-Modify-Write:** Writes conditionally modify only the byte lanes flagged by `dmem_be[3:0]`. Byte 0 modifies bits `[7:0]`, Byte 1 modifies `[15:8]`, Byte 2 modifies `[23:16]`, and Byte 3 modifies `[31:24]`. Unselected bytes preserve their stored contents.
3. **Simultaneous Read & Write (RAW Hazard Definition):** When `dmem_re` and `dmem_we` are asserted in the same cycle to the same address:
   * **Write Wins:** The new data word is committed to RAM on the rising clock edge.
   * **Read Returns Old Data:** Because read data is evaluated combinationally prior to the clock edge, `dmem_rdata` outputs the previous value stored in memory.
4. **Out-of-Range Protection & Sticky Fault:** When an access (`dmem_re || dmem_we`) targets an invalid address (`addr_error = 1`):
   * Write transactions are blocked from modifying RAM.
   * Read transactions cleanly return `32'h0000_0000`.
   * The debug flag `access_fault` is asserted and latches high ("sticky"), remaining active across subsequent valid transactions until cleared by active-low hardware reset (`!rst_n`).

---

## 4. Verification & Test Summary

All modules have been verified through self-checking unit testbenches under Icarus Verilog:

| Testbench | Scope / Focus | Total Tests | Status |
| :--- | :--- | :---: | :---: |
| `tb_decoder.v` | Base/top data memory boundaries, middle indices, instruction memory space, unaligned/out-of-bounds addresses | 16 | **16 / 16 PASSED** |
| `tb_dmem.v` | Zero-initialization, full-word store/load, write-enable gating, 4 individual byte lanes (`be`), halfwords (`be`), and memory limits | 15 | **15 / 15 PASSED** |
| `tb_dmem_ctrl.v` | Full CPU contract suite: word write/read, byte-enable writes, RAW same address, back-to-back accesses, boundaries (`0x1000_0000`, `0x1000_0FFC`, `0x1000_1000`), out-of-range fault latching, simultaneous read/write conflict | 21 | **21 / 21 PASSED** |

**Verification Outcome: 52 / 52 Tests Passed with zero `'X'` (unknown) states.**

---

## 5. Waveform Deliverables (`waves/`)

The waveform deliverables specified in Section 5 are recorded in `waves/tb_dmem_ctrl.vcd` and summarized in `waves/dmem_timing_table.txt` and `waves/dmem_waveform.svg`:

1. **Write/Read Sequence:**
   * Cycles 1–3 demonstrate writing `32'hDEADBEEF` with `dmem_be = 4'b1111` to address `0x1000_0010` and immediately reading back `32'hDEADBEEF` with `dmem_ready = 1`.
   * Cycles 7–22 verify incremental byte-by-byte and halfword read-modify-write sequences on addresses `0x1000_0020` and `0x1000_0024`.
2. **Out-of-Range Access & Sticky Fault:**
   * Cycle 47 accesses out-of-range address `0x1000_1000` with `dmem_re = 1`.
   * `dmem_rdata` outputs `32'h0000_0000`.
   * `access_fault` transitions from `0` to `1` on Cycle 48 and remains continuously high through subsequent valid accesses (Cycle 51) until asynchronous system reset is applied.
