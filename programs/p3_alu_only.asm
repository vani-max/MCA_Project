# ==============================================================================
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
