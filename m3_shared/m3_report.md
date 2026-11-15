# Project 9: Instruction and Data Memory Hierarchy
## Member 3 (M3) Deliverable Report: Shared-Memory (Von Neumann) Comparison Design
**Course:** Modern Computer Architecture, B.Tech (CS&AI)
**Assigned Subsystem:** Shared memory (`shared_mem.v`) + arbiter (`mem_arbiter.v`)
**Deliverable Files:** `shared_mem.v`, `mem_arbiter.v`, `tb_arbiter.v`, `tb_shared_mem.v`, `tb_density.v`, `waves/`

---

### 1. Design Description (for the report)

The shared-memory design is the Von Neumann counterpart of the Harvard design. Instructions and
data live in **one 8 KB memory array with a single address/data port**. The CPU still sees two
ports (the Section 3.1 instruction port and the Section 3.2 data port), so `shared_mem` can be
swapped for the Harvard pair (M1 `imem_top` + M2 `dmem_ctrl`) without changing the CPU or the
programs.

- **Memory core (`shared_mem_core`):** 2048 × 32-bit words. The program region
  `0x0000_0000–0x0000_0FFF` maps to words 0–1023, and the data region `0x1000_0000–0x1000_0FFF`
  maps to words 1024–2047 (index = `{addr[28], addr[11:2]}`). Reads are combinational. Writes are
  synchronous with byte enables. `PROG_FILE` and `DATA_FILE` are loaded with `$readmemh` into the
  two halves, so the same `.hex` / `_data.hex` files run unchanged on both designs.
- **Arbiter (`mem_arbiter`):** purely combinational, with **data priority**. If `dmem_re` or
  `dmem_we` is high, the port is given to the data access, `dmem_ready = 1`, and `imem_ready = 0`,
  so the CPU holds its PC. Otherwise the port serves the fetch and `imem_ready = 1`. The arbiter
  needs no state: the contract requires the CPU to hold `imem_addr` while `imem_ready = 0`, so the
  delayed fetch is served on the first free cycle. Stores follow the Section 3.2 rule (written only
  on `dmem_we && dmem_ready`).
- **Counters:** `conflict_count` increases every cycle in which a fetch is requested but delayed
  (`imem_req && (dmem_re || dmem_we)`). The sticky `access_fault` flag is set by data accesses to
  unmapped addresses. Both reset asynchronously with `rst_n`. Memory contents are kept across
  reset, and stores are blocked while reset is asserted.

### 2. Verification Summary
- `tb_arbiter.v`: **34/34** checks pass (all request combinations, byte enables, unmapped
  addresses, re+we, no X).
- `tb_shared_mem.v`: **75/75** checks pass, both with M3's own program and with M1's unchanged
  `prog_test.hex`. It covers fetch only, data only, fetch + load, fetch + store, 8 consecutive
  loads (the fetch starves, then gets the right instruction), a 6-store burst during a stall
  (exactly 6 writes, none lost or duplicated, neighbouring words untouched), reset during a stall,
  boundaries, and a 200-cycle random trace where `conflict_count` equals the number of overlap
  cycles. No X/Z values appear on any output in any cycle.
- `waves/conflict_log.txt` and `waves/m3_conflict_waveform.svg` show the stall behaviour
  cycle by cycle.

### 3. Analysis Note: Conflict Behaviour and Expected Stall Cycles

**When does a stall happen?** A stall happens only in a cycle where the CPU wants an instruction
*and* a load or store needs the port at the same time. The data access wins, and the fetch slips
by exactly one cycle per such overlap. A run of *k* back-to-back data accesses delays a waiting
fetch by *k* cycles, and it is always served on the first cycle without a data request, so a
fetch can never be starved forever.

**How many stall cycles?** Take a CPU that fetches the next instruction while the current one
executes (2-stage Fetch | Execute). Every load or store overlaps one fetch, except a load/store
that is the last instruction. For *N* instructions with *M* loads/stores (density *d = M/N*):

| | Cycles | CPI |
|---|---|---|
| Harvard | N + 1 | ≈ 1 |
| Shared  | N + 1 + M | ≈ 1 + d |

So **stall cycles ≈ number of loads + stores**, and the shared design's slowdown ≈ *d*.
`tb_density.v` measures this on the hardware (N = 100, `waves/density_sweep.csv`), and every
point matches the formula exactly:

| Load/store density | Loads + stores | Conflicts (stall cycles) | Shared cycles | Harvard cycles | Shared CPI | Slowdown |
|---:|---:|---:|---:|---:|---:|---:|
| 0 %   | 0   | 0  | 101 | 101 | 1.01 | 0 % |
| 25 %  | 25  | 25 | 126 | 101 | 1.26 | 24 % |
| 50 %  | 50  | 50 | 151 | 101 | 1.51 | 49 % |
| 75 %  | 75  | 75 | 176 | 101 | 1.76 | 74 % |
| 100 % | 100 | 99 | 200 | 101 | 2.00 | 98 % |

(At 100 %, the last instruction's store has no following fetch to collide with, so there are 99
conflicts, not 100.)

**What to expect for the test programs (Section 8):**
- `p3_alu_only`: d ≈ 0, so shared ≈ Harvard (almost no stalls).
- `p1_array_sum`, `p4_max_search`, `p5_mixed_loop`: one load per loop of about 4–6 instructions
  (d ≈ 0.15–0.25), so roughly 15–25 % more cycles.
- `p2_mem_copy`: a load and a store in every loop iteration (d ≈ 0.33–0.5), so the biggest gap.
- In the integrated system, M5's measured stall cycles for `top_shared` should equal M3's
  `conflict_count`.

**Dependency on the CPU design (note for M4/M5).** These numbers assume the CPU overlaps the next
fetch with the current data access. A multi-cycle CPU that never fetches during its memory step
would show zero conflicts (its CPI is already higher on both designs). A single-cycle CPU whose
`dmem_re`/`dmem_we` comes combinationally from `imem_rdata` would form a combinational loop
through this arbiter. A 2-stage pipeline (or latching the instruction in an IR before the data
access) avoids both problems.
