# ==============================================================================
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
