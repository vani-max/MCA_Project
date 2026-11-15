#!/usr/bin/env python3
"""
Waveform visualizer for Project 9 Member 1 (Instruction Path)
Generates an SVG waveform and a formatted text timing table from ipath_fetch.vcd
"""

import os
import re

INSTRUCTION_MAP = {
    0x00500093: "addi x1, x0, 5",
    0x00A00113: "addi x2, x0, 10",
    0x002081B3: "add x3, x1, x2",
    0x40118233: "sub x4, x3, x1",
    0x0020F2B3: "and x5, x1, x2",
    0x0020E333: "or x6, x1, x2",
    0x00002383: "lw x7, 0(x0)",
    0x00702023: "sw x7, 0(x0)",
    0x00208463: "beq x1, x2, +8",
    0x00209463: "bne x1, x2, +8",
    0x00C000EF: "jal x1, +12",
    0x00000013: "nop",
    0x00100093: "addi x1, x0, 1",
    0x00200113: "addi x2, x0, 2",
    0x00300193: "addi x3, x0, 3",
    0x0000006F: "halt (jal x0, 0)",
}

def parse_vcd(vcd_path):
    # Mapping identifiers
    sig_map = {}
    with open(vcd_path, "r") as f:
        lines = f.readlines()

    header = True
    changes = []
    current_time = 0

    id_to_name = {
        "!": "imem_ready",
        "\"": "pc",
        "#": "instr",
        "$": "branch_taken",
        "%": "branch_target",
        "&": "clk",
        "'": "rst_n",
        "(": "stall",
    }

    state = {name: 0 for name in id_to_name.values()}

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("$enddefinitions"):
            header = False
            continue
        if header:
            continue

        if line.startswith("#"):
            current_time = int(line[1:])
            continue

        # Check binary or bit change
        if line.startswith("b"):
            parts = line.split()
            val_str = parts[0][1:]
            var_id = parts[1]
            if var_id in id_to_name:
                var_name = id_to_name[var_id]
                try:
                    val = int(val_str, 2)
                except ValueError:
                    val = 0
                state[var_name] = val
                changes.append((current_time, dict(state)))
        elif line[0] in "01xzXZ":
            val = int(line[0]) if line[0] in "01" else 0
            var_id = line[1:]
            if var_id in id_to_name:
                var_name = id_to_name[var_id]
                state[var_name] = val
                changes.append((current_time, dict(state)))

    return changes

def generate_timing_table(changes, out_path):
    # Sample at posedges or key events
    rows = []
    seen_times = set()

    # Time scale in VCD is 1ps, clock period is 10ns = 10000ps
    # Let's sample each posedge (1ns after rising edge)
    clk_old = 0
    for t, st in changes:
        if st["clk"] == 1 and clk_old == 0 and t > 12000:
            # Posedge!
            t_sample = t + 1000 # 1ns after posedge
            # Find state at t_sample
            sample_state = st
            for t_sub, st_sub in changes:
                if t_sub <= t_sample:
                    sample_state = st_sub
                else:
                    break

            pc_val = sample_state["pc"]
            instr_val = sample_state["instr"]
            stall = sample_state["stall"]
            branch = sample_state["branch_taken"]
            ready = sample_state["imem_ready"]
            mnem = INSTRUCTION_MAP.get(instr_val, f"0x{instr_val:08x}")

            time_ns = t // 1000
            rows.append((time_ns, pc_val, instr_val, mnem, stall, branch, ready))
        clk_old = st["clk"]

    # Also capture initial state at t=13ns
    init_state = None
    for t, st in changes:
        if t <= 13000:
            init_state = st
    if init_state:
        pc_val = init_state["pc"]
        instr_val = init_state["instr"]
        mnem = INSTRUCTION_MAP.get(instr_val, f"0x{instr_val:08x}")
        rows.insert(0, (13, pc_val, instr_val, mnem, init_state["stall"], init_state["branch_taken"], init_state["imem_ready"]))

    with open(out_path, "w") as f:
        f.write("=" * 96 + "\n")
        f.write("Project 9 - Member 1 (M1): Instruction Path Cycle-by-Cycle Timing Log\n")
        f.write("=" * 96 + "\n")
        f.write(f"{'Time (ns)':<10} | {'PC':<12} | {'Instruction':<12} | {'Mnemonic':<24} | {'Stall':<6} | {'Branch':<7} | {'Ready':<5}\n")
        f.write("-" * 96 + "\n")
        for r in rows:
            f.write(f"{r[0]:<10} | 0x{r[1]:08x}   | 0x{r[2]:08x}   | {r[3]:<24} | {r[4]:<6} | {r[5]:<7} | {r[6]:<5}\n")
        f.write("=" * 96 + "\n")

    return rows

def generate_svg(rows, svg_path):
    width = 1100
    row_height = 42
    num_signals = 8
    margin_left = 160
    margin_top = 70
    plot_width = width - margin_left - 40
    num_cycles = len(rows)
    cycle_width = plot_width / max(num_cycles, 1)
    height = margin_top + num_signals * row_height + 40

    signals = [
        ("clk", "Digital Clock (100 MHz)"),
        ("rst_n", "Reset (Active-low)"),
        ("stall", "Pipeline Stall"),
        ("branch_taken", "Branch Taken"),
        ("branch_target", "Branch Target"),
        ("pc", "Program Counter (PC)"),
        ("instr", "Instruction (Fetched)"),
        ("imem_ready", "IMEM Ready"),
    ]

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" style="background-color: #1e1e2e; font-family: monospace;">')
    svg.append(f'<text x="{width//2}" y="32" fill="#cdd6f4" font-size="18" font-weight="bold" text-anchor="middle">Project 9 M1: Instruction Fetch Path Waveform (Sequential Fetch + Stall + Branch)</text>')
    svg.append(f'<text x="{width//2}" y="52" fill="#a6adc8" font-size="12" text-anchor="middle">10+ Sequential Instructions, 2-cycle Stall Hold, Branch Redirect to 0x0000_0030</text>')

    # Grid and cycle markers
    for i, r in enumerate(rows):
        x = margin_left + i * cycle_width
        svg.append(f'<line x1="{x}" y1="{margin_top}" x2="{x}" y2="{margin_top + num_signals * row_height}" stroke="#313244" stroke-width="1" stroke-dasharray="3,3"/>')
        svg.append(f'<text x="{x + cycle_width/2}" y="{margin_top - 8}" fill="#89b4fa" font-size="11" text-anchor="middle">C{i+1}</text>')

    for s_idx, (sig_name, sig_desc) in enumerate(signals):
        y_base = margin_top + s_idx * row_height
        svg.append(f'<text x="{margin_left - 15}" y="{y_base + 24}" fill="#f5c2e7" font-size="13" font-weight="bold" text-anchor="end">{sig_name}</text>')

        for i, r in enumerate(rows):
            x = margin_left + i * cycle_width
            # Draw signal values
            if sig_name == "clk":
                # Clock pulse
                mid_x = x + cycle_width / 2
                svg.append(f'<polyline points="{x},{y_base+30} {mid_x},{y_base+30} {mid_x},{y_base+8} {x+cycle_width},{y_base+8}" fill="none" stroke="#a6e3a1" stroke-width="2"/>')
            elif sig_name == "rst_n":
                val = 1 if i > 0 else 0
                y_val = y_base + 8 if val == 1 else y_base + 30
                svg.append(f'<line x1="{x}" y1="{y_val}" x2="{x+cycle_width}" y2="{y_val}" stroke="#94e2d5" stroke-width="2"/>')
            elif sig_name == "stall":
                val = r[4]
                y_val = y_base + 8 if val == 1 else y_base + 30
                col = "#f38ba8" if val == 1 else "#6c7086"
                svg.append(f'<line x1="{x}" y1="{y_val}" x2="{x+cycle_width}" y2="{y_val}" stroke="{col}" stroke-width="{3 if val else 1.5}"/>')
            elif sig_name == "branch_taken":
                val = r[5]
                y_val = y_base + 8 if val == 1 else y_base + 30
                col = "#fab387" if val == 1 else "#6c7086"
                svg.append(f'<line x1="{x}" y1="{y_val}" x2="{x+cycle_width}" y2="{y_val}" stroke="{col}" stroke-width="{3 if val else 1.5}"/>')
            elif sig_name == "branch_target":
                b_tgt = "0x00000030" if r[5] == 1 else "0x00000000"
                svg.append(f'<rect x="{x+1}" y="{y_base+6}" width="{cycle_width-2}" height="24" rx="3" fill="#313244" stroke="#fab387" stroke-width="1"/>')
                svg.append(f'<text x="{x + cycle_width/2}" y="{y_base+22}" fill="#cdd6f4" font-size="9" text-anchor="middle">{b_tgt[2:]}</text>')
            elif sig_name == "pc":
                pc_hex = f"{r[1]:02X}"
                svg.append(f'<rect x="{x+1}" y="{y_base+6}" width="{cycle_width-2}" height="24" rx="3" fill="#313244" stroke="#89b4fa" stroke-width="1.5"/>')
                svg.append(f'<text x="{x + cycle_width/2}" y="{y_base+22}" fill="#89b4fa" font-size="10" font-weight="bold" text-anchor="middle">0x{pc_hex}</text>')
            elif sig_name == "instr":
                mnem = r[3].split()[0] # e.g. addi, lw, etc.
                svg.append(f'<rect x="{x+1}" y="{y_base+6}" width="{cycle_width-2}" height="24" rx="3" fill="#45475a" stroke="#f9e2af" stroke-width="1.5"/>')
                svg.append(f'<text x="{x + cycle_width/2}" y="{y_base+22}" fill="#f9e2af" font-size="10" font-weight="bold" text-anchor="middle">{mnem}</text>')
            elif sig_name == "imem_ready":
                y_val = y_base + 8
                svg.append(f'<line x1="{x}" y1="{y_val}" x2="{x+cycle_width}" y2="{y_val}" stroke="#a6e3a1" stroke-width="2"/>')

    svg.append('</svg>')

    with open(svg_path, "w") as f:
        f.write("\n".join(svg))

if __name__ == "__main__":
    vcd_path = "m1_ipath/waves/ipath_fetch.vcd"
    if os.path.exists(vcd_path):
        changes = parse_vcd(vcd_path)
        rows = generate_timing_table(changes, "m1_ipath/waves/ipath_timing_table.txt")
        generate_svg(rows, "m1_ipath/waves/ipath_fetch_waveform.svg")
        print("Generated waveform SVG and timing table successfully!")
