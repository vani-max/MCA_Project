# ==============================================================================
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
