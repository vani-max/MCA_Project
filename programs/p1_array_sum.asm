# ==============================================================================
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
