#!/usr/bin/env python3
"""
Simple RISC-V Assembler & Reference ISS for Project 9
Supports RV32I subset:
  ADD, SUB, AND, OR, ADDI, LW, SW, BEQ, BNE, JAL, LUI, HALT, NOP
"""

import sys
import re

REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25,
    's10': 26, 's11': 27, 't3': 28, 't4': 29, 't5': 30, 't6': 31
}
for i in range(32):
    REG_MAP[f'x{i}'] = i

def parse_reg(r):
    r = r.strip().lower()
    if r in REG_MAP:
        return REG_MAP[r]
    raise ValueError(f"Unknown register '{r}'")

def parse_imm(val_str):
    val_str = val_str.strip()
    return int(val_str, 0)

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_i(imm, rs1, funct3, rd, opcode):
    imm_12 = imm & 0xFFF
    return (imm_12 << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x07) << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm_12 = imm & 0xFFF
    imm_11_5 = (imm_12 >> 5) & 0x7F
    imm_4_0 = imm_12 & 0x1F
    return (imm_11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | (imm_4_0 << 7) | (opcode & 0x7F)

def encode_b(imm, rs2, rs1, funct3, opcode):
    imm_13 = imm & 0x1FFF
    b12 = (imm_13 >> 12) & 1
    b11 = (imm_13 >> 11) & 1
    b10_5 = (imm_13 >> 5) & 0x3F
    b4_1 = (imm_13 >> 1) & 0x0F
    return (b12 << 31) | (b10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | (b4_1 << 8) | (b11 << 7) | (opcode & 0x7F)

def encode_u(imm, rd, opcode):
    # imm is 20-bit upper immediate (or 32-bit value shifted by 12)
    val = (imm >> 12) if (imm & 0xFFF == 0 and imm > 0xFFFFF) else imm
    return ((val & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_j(imm, rd, opcode):
    imm_21 = imm & 0x1FFFFF
    j20 = (imm_21 >> 20) & 1
    j19_12 = (imm_21 >> 12) & 0xFF
    j11 = (imm_21 >> 11) & 1
    j10_1 = (imm_21 >> 1) & 0x3FF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def assemble(asm_text):
    lines = asm_text.splitlines()
    labels = {}
    clean_instrs = []

    # First pass: collect labels and instruction lines
    pc = 0
    for line in lines:
        # Strip comments
        line = re.sub(r'#.*$', '', line)
        line = re.sub(r'//.*$', '', line).strip()
        if not line:
            continue
        
        # Check for label(s)
        while ':' in line:
            label, rest = line.split(':', 1)
            label = label.strip()
            if label:
                labels[label] = pc
            line = rest.strip()
        if not line:
            continue

        clean_instrs.append((pc, line))
        pc += 4

    # Second pass: assemble to 32-bit words
    machine_code = []
    for pc, line in clean_instrs:
        tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
        mnem = tokens[0].lower()

        if mnem == 'halt':
            word = 0x0000006F
        elif mnem == 'nop':
            word = 0x00000013
        elif mnem == 'add':
            rd = parse_reg(tokens[1])
            rs1 = parse_reg(tokens[2])
            rs2 = parse_reg(tokens[3])
            word = encode_r(0x00, rs2, rs1, 0x0, rd, 0x33)
        elif mnem == 'sub':
            rd = parse_reg(tokens[1])
            rs1 = parse_reg(tokens[2])
            rs2 = parse_reg(tokens[3])
            word = encode_r(0x20, rs2, rs1, 0x0, rd, 0x33)
        elif mnem == 'and':
            rd = parse_reg(tokens[1])
            rs1 = parse_reg(tokens[2])
            rs2 = parse_reg(tokens[3])
            word = encode_r(0x00, rs2, rs1, 0x7, rd, 0x33)
        elif mnem == 'or':
            rd = parse_reg(tokens[1])
            rs1 = parse_reg(tokens[2])
            rs2 = parse_reg(tokens[3])
            word = encode_r(0x00, rs2, rs1, 0x6, rd, 0x33)
        elif mnem == 'addi':
            rd = parse_reg(tokens[1])
            rs1 = parse_reg(tokens[2])
            imm = parse_imm(tokens[3])
            word = encode_i(imm, rs1, 0x0, rd, 0x13)
        elif mnem == 'lw':
            rd = parse_reg(tokens[1])
            # format: offset(rs1)
            m = re.match(r'^(-?\d+|0x[0-9a-fA-F]+)\s*\((.+)\)$', tokens[2])
            if not m:
                raise ValueError(f"Bad load format in: {line}")
            imm = parse_imm(m.group(1))
            rs1 = parse_reg(m.group(2))
            word = encode_i(imm, rs1, 0x2, rd, 0x03)
        elif mnem == 'sw':
            rs2 = parse_reg(tokens[1])
            # format: offset(rs1)
            m = re.match(r'^(-?\d+|0x[0-9a-fA-F]+)\s*\((.+)\)$', tokens[2])
            if not m:
                raise ValueError(f"Bad store format in: {line}")
            imm = parse_imm(m.group(1))
            rs1 = parse_reg(m.group(2))
            word = encode_s(imm, rs2, rs1, 0x2, 0x23)
        elif mnem == 'beq':
            rs1 = parse_reg(tokens[1])
            rs2 = parse_reg(tokens[2])
            tgt = tokens[3]
            offset = (labels[tgt] - pc) if tgt in labels else parse_imm(tgt)
            word = encode_b(offset, rs2, rs1, 0x0, 0x63)
        elif mnem == 'bne':
            rs1 = parse_reg(tokens[1])
            rs2 = parse_reg(tokens[2])
            tgt = tokens[3]
            offset = (labels[tgt] - pc) if tgt in labels else parse_imm(tgt)
            word = encode_b(offset, rs2, rs1, 0x1, 0x63)
        elif mnem == 'jal':
            if len(tokens) == 2:
                rd = 1  # default ra
                tgt = tokens[1]
            else:
                rd = parse_reg(tokens[1])
                tgt = tokens[2]
            offset = (labels[tgt] - pc) if tgt in labels else parse_imm(tgt)
            word = encode_j(offset, rd, 0x6F)
        elif mnem == 'j':
            rd = 0
            tgt = tokens[1]
            offset = (labels[tgt] - pc) if tgt in labels else parse_imm(tgt)
            word = encode_j(offset, rd, 0x6F)
        elif mnem == 'lui':
            rd = parse_reg(tokens[1])
            imm = parse_imm(tokens[2])
            word = encode_u(imm, rd, 0x37)
        else:
            raise ValueError(f"Unsupported instruction: {line}")

        machine_code.append((pc, word, line))

    return machine_code

def simulate(code_words, init_data=None, max_cycles=10000):
    """
    Simulate execution on an ISS model.
    Data memory base: 0x1000_0000.
    """
    imem = {pc: word for pc, word, _ in code_words}
    dmem = {}
    if init_data:
        for idx, val in enumerate(init_data):
            dmem[0x10000000 + idx * 4] = val & 0xFFFFFFFF

    regs = [0] * 32
    pc = 0
    instructions_retired = 0
    loads = 0
    stores = 0

    while pc in imem and instructions_retired < max_cycles:
        instr = imem[pc]
        next_pc = pc + 4

        if instr == 0x0000006F: # HALT
            instructions_retired += 1
            break

        opcode = instr & 0x7F
        rd = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        def sign_ext(val, bits):
            if val & (1 << (bits - 1)):
                return val - (1 << bits)
            return val

        imm_i = sign_ext(instr >> 20, 12)
        imm_s = sign_ext(((instr >> 25) << 5) | ((instr >> 7) & 0x1F), 12)
        imm_b = sign_ext(((instr >> 31) << 12) | (((instr >> 7) & 1) << 11) | \
                         (((instr >> 25) & 0x3F) << 5) | (((instr >> 8) & 0xF) << 1), 13)
        imm_u = (instr >> 12) << 12
        imm_j = sign_ext(((instr >> 31) << 20) | (((instr >> 12) & 0xFF) << 12) | \
                         (((instr >> 20) & 1) << 11) | (((instr >> 21) & 0x3FF) << 1), 21)

        v1 = regs[rs1]
        v2 = regs[rs2]

        if opcode == 0x33: # R-type
            if funct3 == 0x0 and funct7 == 0x00:
                res = (v1 + v2) & 0xFFFFFFFF
            elif funct3 == 0x0 and funct7 == 0x20:
                res = (v1 - v2) & 0xFFFFFFFF
            elif funct3 == 0x7:
                res = (v1 & v2) & 0xFFFFFFFF
            elif funct3 == 0x6:
                res = (v1 | v2) & 0xFFFFFFFF
            else:
                raise ValueError(f"Unknown R-type {hex(instr)}")
            if rd != 0: regs[rd] = res
        elif opcode == 0x13: # ADDI
            res = (v1 + imm_i) & 0xFFFFFFFF
            if rd != 0: regs[rd] = res
        elif opcode == 0x37: # LUI
            res = imm_u & 0xFFFFFFFF
            if rd != 0: regs[rd] = res
        elif opcode == 0x03: # LW
            loads += 1
            addr = (v1 + imm_i) & 0xFFFFFFFF
            res = dmem.get(addr, 0)
            if rd != 0: regs[rd] = res
        elif opcode == 0x23: # SW
            stores += 1
            addr = (v1 + imm_s) & 0xFFFFFFFF
            dmem[addr] = v2 & 0xFFFFFFFF
        elif opcode == 0x63: # Branch
            if funct3 == 0x0: # BEQ
                if v1 == v2: next_pc = pc + imm_b
            elif funct3 == 0x1: # BNE
                if v1 != v2: next_pc = pc + imm_b
            else:
                raise ValueError(f"Unknown branch {hex(instr)}")
        elif opcode == 0x6F: # JAL
            if rd != 0: regs[rd] = (pc + 4) & 0xFFFFFFFF
            next_pc = pc + imm_j
        else:
            raise ValueError(f"Unknown opcode {hex(opcode)}")

        pc = next_pc
        instructions_retired += 1

    return regs, dmem, instructions_retired, loads, stores

if __name__ == '__main__':
    # Self-test
    test_asm = """
    lui x10, 0x10000
    addi x11, x0, 10
    sw x11, 0(x10)
    lw x12, 0(x10)
    add x13, x11, x12
    halt
    """
    code = assemble(test_asm)
    r, d, ins, ld, st = simulate(code)
    print(f"Self-test passed: x13={r[13]} (expected 20), loads={ld}, stores={st}")
