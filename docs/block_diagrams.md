
# M5 - Architecture Block Diagrams

## 1. Harvard Architecture

```mermaid
flowchart TD
    CPU[CPU Core]
    IC[Instruction Memory]
    DC[Data Memory Controller]
    IM[Data Memory]

    CPU -->|Instruction Address and Request| IC
    IC -->|Instruction Data and Ready| CPU

    CPU -->|Data Address, Read/Write, Write Data| DC
    DC -->|Read Data and Ready| CPU
    DC --> IM
```

The Harvard architecture uses separate instruction and data memory paths. This allows instruction fetching and data access to take place independently.

## 2. Shared Memory Architecture

```mermaid
flowchart TD
    CPU[CPU Core]
    ARB[Memory Arbiter]
    MEM[Shared Memory]

    CPU -->|Instruction Request| ARB
    CPU -->|Data Read/Write Request| ARB
    ARB -->|Instruction Data and Ready| CPU
    ARB -->|Data Read Data and Ready| CPU
    ARB -->|Selected Memory Access| MEM
    MEM -->|Read Data| ARB
```

The shared architecture uses one memory interface for both instructions and data. The arbiter gives priority to data accesses when instruction fetching and data access conflict. Instruction fetching is delayed during such conflicts.

## 3. Architecture Comparison

| Feature | Harvard | Shared Memory |
|---|---|---|
| Instruction memory | Separate | Shared |
| Data memory | Separate | Shared |
| Memory access | Independent paths | Arbitration required |
| Instruction/data conflict | Avoided by separate paths | Possible |
| Expected stalls | Lower | Higher during conflicts |
