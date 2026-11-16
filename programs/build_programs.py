#!/usr/bin/env python3
"""
Generate and verify all 5 test programs for Project 9 M4 deliverable.
Produces:
  programs/p1_array_sum{.asm, .hex, _data.hex, _expected.txt}
  programs/p2_mem_copy{.asm, .hex, _data.hex, _expected.txt}
  programs/p3_alu_only{.asm, .hex, _data.hex, _expected.txt}
  programs/p4_max_search{.asm, .hex, _data.hex, _expected.txt}
  programs/p5_mixed_loop{.asm, .hex, _data.hex, _expected.txt}
"""

import os
from assembler import assemble, simulate

PROGRAMS = {}

# ------------------------------------------------------------------------------
# Program 1: p1_array_sum (Load-heavy)
# Sum 16 words from data memory (0x1000_0000 to 0x1000_003C) and store sum to 0x1000_0040
# ------------------------------------------------------------------------------
p1_data = [(i + 1) * 10 for i in range(16)] # 10, 20, 30 ... 160
p1_asm = """# ==============================================================================
# Program 1: p1_array_sum
# Goal: Sum 16 words from data memory (0x1000_0000 - 0x1000_003C)
#       Store final sum at 0x1000_0040.
# Registers:
#   x10 : Pointer to current data memory word
#   x11 : Accumulator (sum)
#   x12 : Loop counter (remaining elements)
#   x13 : Loaded array element
# ==============================================================================

    lui     x10, 0x10000        # x10 = 0x10000000 (Data memory base address)
    addi    x11, x0, 0          # x11 = 0 (Initialize sum accumulator to 0)
    addi    x12, x0, 16         # x12 = 16 (Loop counter = 16 words)

loop:
    lw      x13, 0(x10)         # Load word from memory: x13 = MEM[x10]
    add     x11, x11, x13       # Accumulate: sum = sum + element
    addi    x10, x10, 4         # Advance pointer to next word (+4 bytes)
    addi    x12, x12, -1        # Decrement counter
    bne     x12, x0, loop       # If counter != 0, continue loop

    lui     x10, 0x10000        # Reload base address 0x10000000
    sw      x11, 64(x10)        # Store final sum to 0x1000_0040 (offset 64)
    halt                        # Terminate program
"""
PROGRAMS['p1_array_sum'] = (p1_asm, p1_data)

# ------------------------------------------------------------------------------
# Program 2: p2_mem_copy (Back-to-back Loads and Stores)
# Copy 32 words from 0x1000_0000 to 0x1000_0080
# ------------------------------------------------------------------------------
p2_data = [i + 1 for i in range(32)] # 1, 2, ... 32
p2_asm = """# ==============================================================================
# Program 2: p2_mem_copy
# Goal: Copy 32 words from source (0x1000_0000) to destination (0x1000_0080)
#       Worst-case benchmark for shared memory (back-to-back load & store).
# Registers:
#   x10 : Source pointer (0x1000_0000 .. 0x1000_007C)
#   x11 : Destination pointer (0x1000_0080 .. 0x1000_00FC)
#   x12 : Loop counter (32 iterations)
#   x13 : Temporary data transfer register
# ==============================================================================

    lui     x10, 0x10000        # x10 = 0x1000_0000 (Source base address)
    lui     x11, 0x10000        # x11 = 0x1000_0000
    addi    x11, x11, 128       # x11 = 0x1000_0080 (Destination base address)
    addi    x12, x0, 32         # x12 = 32 (Count = 32 words)

copy_loop:
    lw      x13, 0(x10)         # Load word from source: x13 = MEM[x10]
    sw      x13, 0(x11)         # Store word to destination: MEM[x11] = x13
    addi    x10, x10, 4         # Advance source pointer
    addi    x11, x11, 4         # Advance destination pointer
    addi    x12, x12, -1        # Decrement counter
    bne     x12, x0, copy_loop  # Repeat until 32 words copied

    halt                        # Terminate program
"""
PROGRAMS['p2_mem_copy'] = (p2_asm, p2_data)

# ------------------------------------------------------------------------------
# Program 3: p3_alu_only (ALU compute chain, zero memory accesses)
# Computes Fibonacci & arithmetic operations purely in registers
# ------------------------------------------------------------------------------
p3_data = [] # No data memory accesses
p3_asm = """# ==============================================================================
# Program 3: p3_alu_only
# Goal: Long chain of arithmetic & logic operations, zero data accesses.
#       Best case for shared memory (zero memory conflicts).
# Registers:
#   x1, x2 : Fibonacci generator registers
#   x3..x10: Derived arithmetic expressions
#   x11    : Loop counter (20 iterations)
# ==============================================================================

    addi    x1, x0, 1           # F[1] = 1
    addi    x2, x0, 1           # F[2] = 1
    addi    x11, x0, 15         # Loop 15 times to compute Fibonacci numbers

fib_loop:
    add     x3, x1, x2          # x3 = x1 + x2
    add     x1, x2, x0          # x1 = x2
    add     x2, x3, x0          # x2 = x3
    addi    x11, x11, -1        # Decrement counter
    bne     x11, x0, fib_loop   # Continue loop

    # Subsequent ALU operations chain
    add     x4, x2, x1          # x4 = x2 + x1
    sub     x5, x4, x1          # x5 = x4 - x1 (should equal x2)
    and     x6, x4, x5          # x6 = x4 & x5
    or      x7, x4, x5          # x7 = x4 | x5
    addi    x8, x6, 42          # x8 = x6 + 42
    sub     x9, x7, x8          # x9 = x7 - x8
    and     x10, x9, x2         # x10 = x9 & x2
    or      x12, x10, x1        # x12 = x10 | x1
    addi    x13, x12, -100      # x13 = x12 - 100 (signed negative immediate)
    add     x14, x13, x8        # x14 = x13 + x8
    sub     x15, x14, x1        # x15 = x14 - x1

    halt                        # Terminate program
"""
PROGRAMS['p3_alu_only'] = (p3_asm, p3_data)

# ------------------------------------------------------------------------------
# Program 4: p4_max_search (Array search with conditional branches)
# Finds maximum of 16 unsigned values at 0x1000_0000, stores to 0x1000_0040
# ------------------------------------------------------------------------------
p4_data = [45, 12, 89, 34, 102, 67, 23, 95, 54, 78, 11, 60, 33, 99, 15, 82]
p4_asm = """# ==============================================================================
# Program 4: p4_max_search
# Goal: Find maximum value among 16 words in data memory (0x1000_0000 .. 0x1000_003C)
#       Store the maximum at 0x1000_0040.
# Registers:
#   x10 : Pointer to array
#   x11 : Loop counter (16 elements)
#   x12 : Current maximum value
#   x13 : Loaded array element
#   x14 : Difference (x12 - x13)
#   x15 : Mask 0x8000_0000 (sign bit check)
#   x16 : Sign bit of difference
# ==============================================================================

    lui     x10, 0x10000        # x10 = 0x1000_0000 (Data base)
    addi    x11, x0, 16         # x11 = 16 elements
    addi    x12, x0, 0          # x12 = current max = 0
    lui     x15, 0x80000        # x15 = 0x8000_0000 (Sign bit mask)

search_loop:
    lw      x13, 0(x10)         # Load element: x13 = MEM[x10]
    sub     x14, x12, x13       # x14 = current_max - element
    and     x16, x14, x15       # x16 = (current_max - element) & 0x8000_0000
    beq     x16, x0, no_update  # If sign bit is 0, current_max >= element -> skip update
    add     x12, x13, x0        # New max found: current_max = element

no_update:
    addi    x10, x10, 4         # Advance pointer
    addi    x11, x11, -1        # Decrement counter
    bne     x11, x0, search_loop# Loop until all elements processed

    lui     x10, 0x10000        # Reload base
    sw      x12, 64(x10)        # Store maximum value at 0x1000_0040
    halt                        # Terminate program
"""
PROGRAMS['p4_max_search'] = (p4_asm, p4_data)

# ------------------------------------------------------------------------------
# Program 5: p5_mixed_loop (Interleaved loads and ALU computation)
# Computes accumulated transformation: sum += ((elem * 3) + 7) & 0xFF
# ------------------------------------------------------------------------------
p5_data = [(i + 1) * 5 for i in range(16)] # 5, 10, 15 ... 80
p5_asm = """# ==============================================================================
# Program 5: p5_mixed_loop
# Goal: Process 16 words with interleaved arithmetic and loads.
#       Computes sum of ((elem * 3) + 7) & 0xFF, stores final sum to 0x1000_0040.
# Registers:
#   x10 : Pointer to array
#   x11 : Accumulator
#   x12 : Loop counter (16 elements)
#   x13 : Loaded element
#   x14 : Transformed element computation
#   x15 : Mask 0x0000_00FF
# ==============================================================================

    lui     x10, 0x10000        # x10 = 0x1000_0000 (Data base)
    addi    x11, x0, 0          # Accumulator = 0
    addi    x12, x0, 16         # Counter = 16
    addi    x15, x0, 255        # Mask = 0x0000_00FF

mixed_loop:
    lw      x13, 0(x10)         # Load element
    add     x14, x13, x13       # x14 = elem * 2
    add     x14, x14, x13       # x14 = elem * 3
    addi    x14, x14, 7         # x14 = (elem * 3) + 7
    and     x14, x14, x15       # x14 = ((elem * 3) + 7) & 0xFF
    add     x11, x11, x14       # Accumulate into total sum
    addi    x10, x10, 4         # Advance pointer
    addi    x12, x12, -1        # Decrement counter
    bne     x12, x0, mixed_loop # Repeat for all elements

    lui     x10, 0x10000        # Reload base
    sw      x11, 64(x10)        # Store final accumulated sum to 0x1000_0040
    halt                        # Terminate program
"""
PROGRAMS['p5_mixed_loop'] = (p5_asm, p5_data)

def generate_all():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = script_dir

    print("================================================================================")
    print(" Generating and Verifying M4 Test Programs")
    print("================================================================================")

    summary_rows = []

    for name, (asm_src, init_data) in PROGRAMS.items():
        asm_path = os.path.join(out_dir, f"{name}.asm")
        hex_path = os.path.join(out_dir, f"{name}.hex")
        data_hex_path = os.path.join(out_dir, f"{name}_data.hex")
        expected_path = os.path.join(out_dir, f"{name}_expected.txt")

        # 1. Write .asm
        with open(asm_path, "w") as f:
            f.write(asm_src)

        # 2. Assemble to machine code
        code = assemble(asm_src)

        # 3. Write .hex (one 32-bit hex word per line)
        with open(hex_path, "w") as f:
            for pc, word, line in code:
                f.write(f"{word:08x}\n")

        # 4. Write _data.hex (one 32-bit hex word per line)
        with open(data_hex_path, "w") as f:
            for val in init_data:
                f.write(f"{val & 0xFFFFFFFF:08x}\n")

        # 5. Simulate on ISS
        regs, dmem, instrs, loads, stores = simulate(code, init_data)

        # 6. Write _expected.txt
        with open(expected_path, "w") as f:
            f.write(f"# Expected Results for {name}\n")
            f.write(f"# Dynamic instructions retired: {instrs}\n")
            f.write(f"# Total Loads: {loads}\n")
            f.write(f"# Total Stores: {stores}\n\n")
            f.write("[REGISTERS]\n")
            for r in range(32):
                if regs[r] != 0:
                    f.write(f"x{r:<2} = 0x{regs[r]:08x} ({regs[r]})\n")
            f.write("\n[DATA_MEMORY]\n")
            # Dump modified / relevant memory words
            for addr in sorted(dmem.keys()):
                # Only print words within first 64 words of data memory or modified words
                idx = (addr - 0x10000000) // 4
                f.write(f"MEM[0x{addr:08x}] (word {idx:<2}) = 0x{dmem[addr]:08x} ({dmem[addr]})\n")

        summary_rows.append((name, len(code), instrs, loads, stores))
        print(f"Generated {name}: {len(code)} instructions, ISS retired {instrs} instrs (Loads: {loads}, Stores: {stores})")

    print("\nSummary of Test Programs:")
    print(f"{'Program':<16} | {'Code Words':<10} | {'Retired':<8} | {'Loads':<6} | {'Stores':<6}")
    print("-" * 60)
    for r in summary_rows:
        print(f"{r[0]:<16} | {r[1]:<10} | {r[2]:<8} | {r[3]:<6} | {r[4]:<6}")
    print("================================================================================")

if __name__ == "__main__":
    generate_all()
