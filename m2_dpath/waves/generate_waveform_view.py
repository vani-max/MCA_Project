#!/usr/bin/env python3
"""
Waveform visualizer for Project 9 Member 2 (Data Path: Data Memory + Decoder + Controller)
Generates an SVG waveform and a formatted text timing table from tb_dmem_ctrl.vcd
"""

import os
import re

def parse_vcd(vcd_path):
    sig_map = {}
    with open(vcd_path, "r") as f:
        lines = f.readlines()

    header = True
    id_to_name = {}

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("$var"):
            parts = line.split()
            # e.g.: $var wire 32 ! dmem_addr [31:0] $end
            # or:   $var wire 1 " clk $end
            var_type = parts[1]
            var_size = parts[2]
            var_id = parts[3]
            var_name = parts[4]
            # Match top-level signals
            if var_name in ["clk", "rst_n", "dmem_addr", "dmem_wdata", "dmem_re",
                            "dmem_we", "dmem_be", "dmem_rdata", "dmem_ready", "access_fault"]:
                id_to_name[var_id] = var_name
        elif line.startswith("$enddefinitions"):
            header = False
            break

    state = {name: 0 for name in id_to_name.values()}
    changes = []
    current_time = 0

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if header:
            if line.startswith("$enddefinitions"):
                header = False
            continue

        if line.startswith("#"):
            current_time = int(line[1:])
            continue

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
    # Sample state at key clock edges / intervals
    rows = []
    clk_old = 0
    cycle = 0

    for t, st in changes:
        # Detect rising clock edge
        if st.get("clk", 0) == 1 and clk_old == 0 and t >= 30000:
            cycle += 1
            time_ns = t // 1000
            addr = st.get("dmem_addr", 0)
            wdata = st.get("dmem_wdata", 0)
            rdata = st.get("dmem_rdata", 0)
            re = st.get("dmem_re", 0)
            we = st.get("dmem_we", 0)
            be = st.get("dmem_be", 0)
            ready = st.get("dmem_ready", 0)
            fault = st.get("access_fault", 0)

            op = "IDLE"
            if we and re:
                op = "SIMULT_RW"
            elif we:
                op = "STORE"
            elif re:
                op = "LOAD"

            rows.append((cycle, time_ns, op, addr, wdata, be, rdata, ready, fault))
        clk_old = st.get("clk", 0)

    with open(out_path, "w") as f:
        f.write("=" * 115 + "\n")
        f.write(" PROJECT 9 (M2 - DATA PATH) CYCLE-BY-CYCLE TIMING VERIFICATION TABLE\n")
        f.write(" Contract: Section 3.2 CPU Data Port Handshake & R/W Verification\n")
        f.write("=" * 115 + "\n")
        f.write(f"{'Cyc':>4} | {'Time(ns)':>8} | {'Operation':>10} | {'dmem_addr':>10} | {'dmem_wdata':>10} | {'be':>4} | {'dmem_rdata':>10} | {'ready':>5} | {'fault':>5}\n")
        f.write("-" * 115 + "\n")
        for r in rows:
            f.write(f"{r[0]:>4} | {r[1]:>8} | {r[2]:>10} | 0x{r[3]:08X} | 0x{r[4]:08X} | {r[5]:04b} | 0x{r[6]:08X} | {r[7]:>5} | {r[8]:>5}\n")
        f.write("=" * 115 + "\n")

def generate_svg(changes, out_path):
    # Select key time window showing Write/Read Sequence and Out-of-Range Fault
    # Sample every 5ns (half clock period) from 30ns to 220ns
    t_start = 30000   # 30 ns
    t_end   = 230000  # 230 ns
    step    = 5000    # 5 ns

    sample_times = list(range(t_start, t_end + step, step))
    samples = []

    for st_t in sample_times:
        current_state = {}
        for t, st in changes:
            if t <= st_t:
                current_state = st
            else:
                break
        samples.append((st_t // 1000, current_state))

    # SVG layout
    signals = [
        ("clk", "bit"),
        ("rst_n", "bit"),
        ("dmem_ready", "bit"),
        ("dmem_we", "bit"),
        ("dmem_re", "bit"),
        ("dmem_be", "bus"),
        ("dmem_addr", "bus"),
        ("dmem_wdata", "bus"),
        ("dmem_rdata", "bus"),
        ("access_fault", "bit")
    ]

    width = 1200
    row_height = 42
    header_height = 60
    label_width = 150
    height = header_height + len(signals) * row_height + 40
    plot_width = width - label_width - 40

    x_step = plot_width / (len(sample_times) - 1)

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">')
    svg.append('<style>')
    svg.append('  text { font-family: "SF Pro Text", -apple-system, BlinkMacSystemFont, "Segoe UI", monospace; font-size: 12px; }')
    svg.append('  .title { font-size: 16px; font-weight: bold; fill: #1e293b; }')
    svg.append('  .subtitle { font-size: 12px; fill: #64748b; }')
    svg.append('  .lbl { font-weight: 600; fill: #334155; }')
    svg.append('  .grid { stroke: #e2e8f0; stroke-width: 1; stroke-dasharray: 3 3; }')
    svg.append('  .wave-bit { stroke: #2563eb; stroke-width: 2; fill: none; }')
    svg.append('  .wave-fault { stroke: #dc2626; stroke-width: 2.5; fill: none; }')
    svg.append('  .wave-bus-line { stroke: #059669; stroke-width: 1.5; fill: none; }')
    svg.append('  .wave-bus-fill { fill: #ecfdf5; stroke: #059669; stroke-width: 1.5; }')
    svg.append('  .bus-text { font-size: 10px; fill: #065f46; font-weight: 600; text-anchor: middle; }')
    svg.append('</style>')

    # Background
    svg.append(f'<rect width="{width}" height="{height}" fill="#ffffff" rx="8"/>')

    # Title
    svg.append(f'<text x="20" y="30" class="title">Project 9: Member 2 (M2) Data Path Waveform Deliverable</text>')
    svg.append(f'<text x="20" y="48" class="subtitle">Write/Read Transactions, Byte-Enable Masking, and Out-of-Range Access Fault Verification</text>')

    # Vertical grid lines & clock cycles
    for i, (t_ns, _) in enumerate(samples):
        x = label_width + i * x_step
        svg.append(f'<line x1="{x}" y1="{header_height}" x2="{x}" y2="{height - 20}" class="grid"/>')
        if i % 2 == 0:
            svg.append(f'<text x="{x}" y="{header_height - 8}" text-anchor="middle" fill="#94a3b8" font-size="10">{t_ns}ns</text>')

    # Render each signal
    for s_idx, (sig_name, sig_type) in enumerate(signals):
        y_base = header_height + s_idx * row_height + 28
        y_high = y_base - 18
        y_low  = y_base

        svg.append(f'<text x="20" y="{y_base - 5}" class="lbl">{sig_name}</text>')

        if sig_type == "bit":
            line_class = "wave-fault" if sig_name == "access_fault" else "wave-bit"
            pts = []
            for i, (_, st) in enumerate(samples):
                x = label_width + i * x_step
                val = st.get(sig_name, 0)
                y = y_high if val == 1 else y_low
                if i == 0:
                    pts.append(f"M {x} {y}")
                else:
                    prev_y = pts[-1].split()[-1]
                    pts.append(f"L {x} {prev_y} L {x} {y}")
            svg.append(f'<path d="{" ".join(pts)}" class="{line_class}"/>')

        else: # Bus
            # Group contiguous identical values
            segments = []
            cur_val = None
            start_i = 0
            for i, (_, st) in enumerate(samples):
                v = st.get(sig_name, 0)
                if v != cur_val:
                    if cur_val is not None:
                        segments.append((start_i, i, cur_val))
                    cur_val = v
                    start_i = i
            segments.append((start_i, len(samples) - 1, cur_val))

            for (i_start, i_end, val) in segments:
                x1 = label_width + i_start * x_step
                x2 = label_width + i_end * x_step
                w = x2 - x1
                if w <= 0:
                    continue

                if val == 0 and sig_name in ["dmem_wdata", "dmem_re"]:
                    # Flat zero
                    svg.append(f'<line x1="{x1}" y1="{y_low}" x2="{x2}" y2="{y_low}" stroke="#94a3b8" stroke-width="1.5"/>')
                else:
                    # Draw bus envelope
                    poly = f'<polygon points="{x1+3},{y_high} {x2-3},{y_high} {x2},{y_base-9} {x2-3},{y_low} {x1+3},{y_low} {x1},{y_base-9}" class="wave-bus-fill"/>'
                    svg.append(poly)
                    # Label text
                    if sig_name == "dmem_be":
                        txt = f"{val:04b}"
                    else:
                        txt = f"0x{val:08X}"
                    if w > 45:
                        svg.append(f'<text x="{x1 + w/2}" y="{y_base - 5}" class="bus-text">{txt}</text>')

    svg.append('</svg>')

    with open(out_path, "w") as f:
        f.write("\n".join(svg))

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    vcd_file = os.path.join(script_dir, "tb_dmem_ctrl.vcd")
    timing_file = os.path.join(script_dir, "dmem_timing_table.txt")
    svg_file = os.path.join(script_dir, "dmem_waveform.svg")

    if os.path.exists(vcd_file):
        print(f"Parsing VCD: {vcd_file}...")
        changes = parse_vcd(vcd_file)
        generate_timing_table(changes, timing_file)
        print(f"Generated text timing table: {timing_file}")
        generate_svg(changes, svg_file)
        print(f"Generated SVG waveform: {svg_file}")
    else:
        print(f"Error: {vcd_file} not found. Run simulation first.")
