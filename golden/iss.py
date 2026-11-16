
#!/usr/bin/env python3
"""
Golden Reference Instruction Set Simulator (ISS)
Project 9 - Memory Hierarchy Comparison

Supports the RV32I instruction subset used by the project:
ADD, SUB, AND, OR, ADDI, LUI, LW, SW, BEQ, BNE, JAL, HALT.

Instruction memory base : 0x00000000
Data memory base        : 0x10000000
Memory size             : 4 KB (1024 words)

Usage:
    python3 golden/iss.py programs/p1_array_sum.hex

Outputs:
    golden/output/<program>_regs.txt
    golden/output/<program>_data.txt
    golden/output/<program>_stats.txt
"""

import argparse
from pathlib import Path

DATA_BASE = 0x10000000
MEMORY_WORDS = 1024
HALT_WORD = 0x0000006F
MASK32 = 0xFFFFFFFF


def sign_extend(value, bits):
    """Convert a signed immediate to a 32-bit Python integer."""
    sign_bit = 1 << (bits - 1)
    if value & sign_bit:
        return value - (1 << bits)
    return value


def read_hex_file(filename):
    """Read one hexadecimal 32-bit word per line."""
    words = []

    with open(filename, "r") as file:
        for line in file:
            line = line.split("#")[0].strip()
            if not line:
                continue
            words.append(int(line, 16) & MASK32)

    return words


def decode_immediates(instr):
    """Decode RISC-V I, S, B, U and J immediates."""

    imm_i = sign_extend(instr >> 20, 12)

    imm_s_raw = (
        ((instr >> 25) << 5)
        | ((instr >> 7) & 0x1F)
    )
    imm_s = sign_extend(imm_s_raw, 12)

    imm_b_raw = (
        ((instr >> 31) << 12)
        | (((instr >> 7) & 1) << 11)
        | (((instr >> 25) & 0x3F) << 5)
        | (((instr >> 8) & 0xF) << 1)
    )
    imm_b = sign_extend(imm_b_raw, 13)

    imm_u = instr & 0xFFFFF000

    imm_j_raw = (
        ((instr >> 31) << 20)
        | (((instr >> 12) & 0xFF) << 12)
        | (((instr >> 20) & 1) << 11)
        | (((instr >> 21) & 0x3FF) << 1)
    )
    imm_j = sign_extend(imm_j_raw, 21)

    return imm_i, imm_s, imm_b, imm_u, imm_j


def run_iss(program_file, data_file, max_steps=100000):
    """Execute a program and return final machine state."""

    instructions = read_hex_file(program_file)

    if not instructions:
        raise ValueError("Program file is empty.")

    if len(instructions) > MEMORY_WORDS:
        raise ValueError("Program exceeds 4 KB instruction memory.")

    # Instruction memory: byte address -> instruction
    imem = {
        index * 4: word
        for index, word in enumerate(instructions)
    }

    # Data memory: byte address -> 32-bit word
    dmem = {}

    if data_file and Path(data_file).exists():
        initial_data = read_hex_file(data_file)

        if len(initial_data) > MEMORY_WORDS:
            raise ValueError("Initial data exceeds 4 KB.")

        for index, value in enumerate(initial_data):
            dmem[DATA_BASE + index * 4] = value

    # 32 general-purpose registers
    regs = [0] * 32

    pc = 0
    retired = 0
    loads = 0
    stores = 0
    halted = False

    while retired < max_steps:

        if pc not in imem:
            raise RuntimeError(
                f"Program reached invalid instruction address 0x{pc:08X} "
                "before HALT."
            )

        instr = imem[pc]

        # HALT is encoded as JAL x0, 0
        if instr == HALT_WORD:
            retired += 1
            halted = True
            break

        opcode = instr & 0x7F
        rd = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x07
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        imm_i, imm_s, imm_b, imm_u, imm_j = decode_immediates(instr)

        value1 = regs[rs1]
        value2 = regs[rs2]

        next_pc = (pc + 4) & MASK32

        # R-type instructions
        if opcode == 0x33:

            if funct3 == 0x0 and funct7 == 0x00:
                result = value1 + value2

            elif funct3 == 0x0 and funct7 == 0x20:
                result = value1 - value2

            elif funct3 == 0x7 and funct7 == 0x00:
                result = value1 & value2

            elif funct3 == 0x6 and funct7 == 0x00:
                result = value1 | value2

            else:
                raise ValueError(
                    f"Unsupported R-type instruction 0x{instr:08X}"
                )

            if rd != 0:
                regs[rd] = result & MASK32

        # ADDI
        elif opcode == 0x13:

            if funct3 != 0x0:
                raise ValueError("Unsupported immediate instruction.")

            if rd != 0:
                regs[rd] = (value1 + imm_i) & MASK32

        # LUI
        elif opcode == 0x37:

            if rd != 0:
                regs[rd] = imm_u & MASK32

        # LW
        elif opcode == 0x03:

            if funct3 != 0x2:
                raise ValueError("Only LW is supported.")

            address = (value1 + imm_i) & MASK32

            if address < DATA_BASE or address >= DATA_BASE + 4096:
                raise RuntimeError(
                    f"Load address outside data memory: 0x{address:08X}"
                )

            if address % 4 != 0:
                raise RuntimeError("Unaligned LW address.")

            loads += 1
            result = dmem.get(address, 0)

            if rd != 0:
                regs[rd] = result

        # SW
        elif opcode == 0x23:

            if funct3 != 0x2:
                raise ValueError("Only SW is supported.")

            address = (value1 + imm_s) & MASK32

            if address < DATA_BASE or address >= DATA_BASE + 4096:
                raise RuntimeError(
                    f"Store address outside data memory: 0x{address:08X}"
                )

            if address % 4 != 0:
                raise RuntimeError("Unaligned SW address.")

            stores += 1
            dmem[address] = value2 & MASK32

        # BEQ and BNE
        elif opcode == 0x63:

            if funct3 == 0x0:
                if value1 == value2:
                    next_pc = (pc + imm_b) & MASK32

            elif funct3 == 0x1:
                if value1 != value2:
                    next_pc = (pc + imm_b) & MASK32

            else:
                raise ValueError("Unsupported branch instruction.")

        # JAL
        elif opcode == 0x6F:

            if rd != 0:
                regs[rd] = (pc + 4) & MASK32

            next_pc = (pc + imm_j) & MASK32

        else:
            raise ValueError(
                f"Unsupported opcode 0x{opcode:02X} "
                f"at PC 0x{pc:08X}"
            )

        pc = next_pc
        regs[0] = 0
        retired += 1

    if not halted:
        raise RuntimeError(
            f"Program did not HALT within {max_steps} instructions."
        )

    return regs, dmem, retired, loads, stores


def write_outputs(program_file, regs, dmem, retired, loads, stores, outdir):

    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    program_name = Path(program_file).stem

    # Final register file
    reg_file = outdir / f"{program_name}_regs.txt"

    with open(reg_file, "w") as file:
        file.write("FINAL REGISTER FILE\n")
        file.write("===================\n")

        for index, value in enumerate(regs):
            file.write(
                f"x{index:02d} = 0x{value:08X} ({value})\n"
            )

    # Final data memory dump: all 1024 words
    data_dump = outdir / f"{program_name}_data.txt"

    with open(data_dump, "w") as file:
        file.write("FINAL DATA MEMORY DUMP\n")
        file.write("======================\n")

        for index in range(MEMORY_WORDS):
            address = DATA_BASE + index * 4
            value = dmem.get(address, 0)

            file.write(
                f"0x{address:08X}: 0x{value:08X}\n"
            )

    # Execution statistics
    stats_file = outdir / f"{program_name}_stats.txt"

    with open(stats_file, "w") as file:
        file.write(f"Program: {program_name}\n")
        file.write(f"Instructions retired: {retired}\n")
        file.write(f"Loads: {loads}\n")
        file.write(f"Stores: {stores}\n")
        file.write("Halted: YES\n")

    print("\n========== GOLDEN ISS RESULTS ==========")
    print(f"Program              : {program_name}")
    print(f"Instructions retired : {retired}")
    print(f"Load instructions    : {loads}")
    print(f"Store instructions   : {stores}")
    print("Halted               : YES")
    print("---------------------------------------")
    print(f"Register dump        : {reg_file}")
    print(f"Data memory dump     : {data_dump}")
    print(f"Statistics           : {stats_file}")
    print("=======================================\n")


def main():

    parser = argparse.ArgumentParser(
        description="Golden reference ISS for Project 9"
    )

    parser.add_argument(
        "program",
        help="Path to program .hex file"
    )

    parser.add_argument(
        "--data",
        help="Optional initial data memory .hex file"
    )

    parser.add_argument(
        "--outdir",
        default="golden/output",
        help="Directory for output files"
    )

    parser.add_argument(
        "--max-steps",
        type=int,
        default=100000,
        help="Maximum instructions before timeout"
    )

    args = parser.parse_args()

    program_path = Path(args.program)

    if not program_path.exists():
        parser.error(f"Program file not found: {program_path}")

    # Automatically locate the matching data file
    if args.data:
        data_path = Path(args.data)
    else:
        data_path = program_path.with_name(
            program_path.stem + "_data.hex"
        )

    regs, dmem, retired, loads, stores = run_iss(
        program_path,
        data_path,
        args.max_steps
    )

    write_outputs(
        program_path,
        regs,
        dmem,
        retired,
        loads,
        stores,
        args.outdir
    )


if __name__ == "__main__":
    main()
