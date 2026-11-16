# ==============================================================================
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
