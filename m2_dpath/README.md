# Member 2 (M2) — Data Path

This folder contains the data memory subsystem for the project:
- `addr_decoder.v`: checks if the address is within data memory and gets the word index
- `dmem.v`: 1024-word RAM that supports byte enables for writing
- `dmem_ctrl.v`: wraps memory and decoder to connect directly to the CPU

---

## How to run tests

To run all testbenches:

```bash
cd m2_dpath
./run_tests.sh
```

Or run them individually with iverilog:

```bash
# 1. Address decoder test
iverilog -g2012 -o waves/sim_decoder addr_decoder.v tb_decoder.v && vvp waves/sim_decoder

# 2. Data memory test
iverilog -g2012 -o waves/sim_dmem dmem.v tb_dmem.v && vvp waves/sim_dmem

# 3. Controller test
iverilog -g2012 -o waves/sim_dmem_ctrl addr_decoder.v dmem.v dmem_ctrl.v tb_dmem_ctrl.v && vvp waves/sim_dmem_ctrl
```

---

## How it works

### 1. Address Decoder (`addr_decoder.v`)
- Data memory range is `0x1000_0000` to `0x1000_0FFF` (4 KB, 1024 words).
- Takes the 32-bit address and extracts `addr[11:2]` to get the word index (0 to 1023).
- If the address is outside this range, it sets `addr_error = 1`.

### 2. Data Memory (`dmem.v`)
- Holds 1024 words of 32-bit data, initialized to 0 on startup.
- Reading is combinational, so data comes back in the same clock cycle.
- Writing is synchronous on the rising clock edge.
- Uses 4 byte-enable bits (`be[3:0]`) so the CPU can write individual bytes, halfwords, or full words without messing up the rest of the word.

### 3. Controller (`dmem_ctrl.v`)
- Matches the CPU data port interface required by the project.
- In Harvard architecture, data memory has its own path and never stalls, so `dmem_ready` is always 1.
- If an address is out of range, writes are ignored, reads return 0, and a sticky `access_fault` flag stays high until reset.
- If read and write happen at the exact same time, the write commits on the clock edge while the read returns the old value.

---

## Test Results

All testbenches pass with zero unknown ('X') values:
- `tb_decoder.v`: 16 tests passed
- `tb_dmem.v`: 15 tests passed
- `tb_dmem_ctrl.v`: 21 tests passed
- Total: 52 / 52 passed
