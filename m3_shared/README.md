# Member 3 (M3) — Shared-Memory (Von Neumann) Comparison Design
**Project 9:** Instruction and Data Memory Hierarchy (Harvard vs Shared)
**Assigned Modules:** Single-port shared memory (`shared_mem.v`) + Arbiter (`mem_arbiter.v`)

---

## 1. Directory Structure

```
m3_shared/
├── shared_mem.v            # shared_mem_core (one 8 KB single-port array) + shared_mem (top)
├── mem_arbiter.v           # Data-priority arbiter: two CPU ports -> one memory port
├── tb_arbiter.v            # Unit testbench for the arbiter (combinational)
├── tb_shared_mem.v         # System testbench: all required conflict / stall cases
├── tb_density.v            # Analysis testbench: stall cycles vs load/store density
├── hex/
│   ├── m3_prog.hex         # Array-sum test program (RV32I, ends in HALT 0000006f)
│   └── m3_prog_data.hex    # 16 data words: 10, 20, ..., 160
├── run_tests.sh            # Runs every testbench
├── m3_report.md            # Half-page description + analysis note (for M5)
└── waves/
    ├── tb_arbiter.vcd / tb_shared_mem.vcd / tb_density.vcd
    ├── conflict_log.txt          # cycle-by-cycle log incl. conflict_count (deliverable)
    ├── density_sweep.csv         # stall cycles vs load/store density (analysis)
    ├── m3_conflict_waveform.svg  # timing diagram of the stall behaviour (for report/demo)
    └── make_waveform.py          # regenerates the SVG from conflict_log.txt
```

## 2. Quick Start

Requires Icarus Verilog (`brew install icarus-verilog`).

```bash
cd m3_shared
./run_tests.sh                     # all tests + waveforms + CSV
python3 waves/make_waveform.py     # redraw waves/m3_conflict_waveform.svg
open waves/m3_conflict_waveform.svg
```

## 3. Ports (for M5 integration)

`shared_mem #(.PROG_FILE("..."), .DATA_FILE("..."))` exposes **exactly** the Section 3.1 + 3.2
contract ports, so it replaces `imem_top` (M1) + `dmem_ctrl` (M2) with no renaming:

| Port | Dir | Width | Notes |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | rising edge, active-low async reset |
| `imem_addr`, `imem_req` | in | 32, 1 | Section 3.1 |
| `imem_rdata`, `imem_ready` | out | 32, 1 | `imem_ready = 0` while a data access uses the port |
| `dmem_addr`, `dmem_wdata`, `dmem_re`, `dmem_we`, `dmem_be` | in | 32, 32, 1, 1, 4 | Section 3.2 |
| `dmem_rdata`, `dmem_ready` | out | 32, 1 | `dmem_ready` is always 1 (data has priority) |
| `conflict_count` | out | 32 | +1 every cycle a fetch is delayed (`imem_req && (dmem_re \|\| dmem_we)`) |
| `access_fault` | out | 1 | sticky; data access to an unmapped address (same name as M2) |

Memory map (Section 4.1): `0x0000_0000–0x0000_0FFF` program (words 0–1023),
`0x1000_0000–0x1000_0FFF` data (words 1024–2047). Index = `{addr[28], addr[11:2]}`.
Unmapped: fetch → NOP `0x00000013`, load → 0, store ignored.

## 4. Test Summary

| Testbench | Focus | Checks | Status |
|---|---|:---:|:---:|
| `tb_arbiter.v` | idle, fetch only, load only, store only, fetch+load, fetch+store, byte enables, unmapped, re+we, no X | 34 | **34 / 34 PASSED** |
| `tb_shared_mem.v` | reset, unchanged hex (all 2048 words), fetch only, data only, fetch+load, fetch+store, byte/halfword writes, 8 consecutive loads (fetch starves then served), 6-store burst (no store lost or duplicated), reset during stall, unmapped + sticky fault, boundaries, re+we, data port reads program, 200-cycle random trace (`conflict_count` = overlap cycles), no X | 75 | **75 / 75 PASSED** |
| `tb_shared_mem.v` with M1's `prog_test.hex` | same suite on another member's unchanged hex | 75 | **75 / 75 PASSED** |
| `tb_density.v` | stall cycles for 0/25/50/75/100 % load/store density vs analytical model | 10 | **10 / 10 PASSED** |

## 5. Known Limits / Notes for the Team
- Data port can also read/write the program region (that is the Von Neumann property; Harvard cannot).
  Test programs should keep data in `0x1000_xxxx` so both designs give identical results.
- **For M4:** conflicts only show up if the CPU fetches the next instruction while the current one
  accesses data (e.g. 2-stage Fetch | Execute). A single-cycle core whose `dmem_re/we` depends
  combinationally on `imem_rdata` forms a combinational loop with this arbiter; a multi-cycle core
  that never overlaps fetch and data access will show `conflict_count = 0`.
- Full write-up and stall analysis (half-page description for M5): [`m3_report.md`](m3_report.md).
