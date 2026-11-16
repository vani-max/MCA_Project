
# M5 - Memory Hierarchy and System Architecture

## 1. Overview

This part of the project focuses on comparing two memory architectures:
- Harvard Architecture
- Shared Memory Architecture

The objective is to study how separate instruction and data memories compare with a shared memory system in terms of execution performance.

## 2. Harvard Architecture

In Harvard Architecture, instruction memory and data memory are separate.

- Instruction memory stores program instructions.
- Data memory stores values used by the program.
- The CPU can request an instruction and access data independently.
- Separate memory interfaces reduce instruction-fetch and data-access conflicts.

## 3. Shared Memory Architecture

In the shared memory design, instructions and data use the same memory.

- Both instruction fetches and data accesses use a shared memory interface.
- An arbitration mechanism manages simultaneous requests.
- Data memory requests receive priority when a conflict occurs.
- Instruction fetching may be delayed during a data access.

## 4. Memory Map

| Memory | Base Address | Size |
|---|---|---|
| Instruction Memory | 0x00000000 | 4 KB |
| Data Memory | 0x10000000 | 4 KB |

Each memory contains 1024 words of 32 bits.

## 5. Instruction Set

The simulator and CPU support the following instruction subset:

- ADD
- SUB
- AND
- OR
- ADDI
- LW
- SW
- BEQ
- BNE
- JAL
- HALT

## 6. Performance Evaluation

The two architectures are intended to be evaluated using the following measurements:

- Total execution cycles
- Instruction count
- Cycles Per Instruction (CPI)
- Memory stalls
- Load and store operations
- Program pass/fail status

Five test programs are used:
1. p1_array_sum
2. p2_mem_copy
3. p3_alu_only
4. p4_max_search
5. p5_mixed_loop

## 7. Expected Observations

- ALU-only programs are expected to show relatively little difference between the architectures.
- Memory-intensive programs may experience more stalls in the shared memory architecture.
- Harvard Architecture allows independent instruction and data memory accesses.
- Shared Memory Architecture requires arbitration when instruction and data requests conflict.

## 8. Conclusion

The project compares the effect of memory organization on CPU performance. Separate instruction and data memories can reduce memory-access conflicts, while a shared memory architecture requires arbitration to manage competing requests.

Actual performance measurements and synthesis results should be added after successful simulation and synthesis.
