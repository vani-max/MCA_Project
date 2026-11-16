#!/usr/bin/env python3
"""
Waveform and Timing Table Generator for M4 CPU Core
Generates:
  1. waves/m4_timing_table.txt
  2. waves/m4_pipeline_waveform.svg
Illustrates 2-stage pipeline operation, instruction execution, load/store accesses,
stall handling on imem_ready=0 and dmem_ready=0, and branch redirection.
"""

import os

CYCLES_DATA = [
    # Cycle, Time, PC, EX_PC, EX_INSTR, EX_MNEM, ALU_RES, DMEM_ADDR, DMEM_RE, DMEM_WE, STALL, HALT, RF_WE, NOTE
    (1,  "10ns", "00000000", "00000000", "00000013", "NOP",              "00000000", "00000000", 0, 0, 0, 0, 0, "Reset deasserted; Fetch instr 0"),
    (2,  "20ns", "00000004", "00000000", "00f00093", "addi x1, x0, 15",  "0000000f", "00000000", 0, 0, 0, 0, 1, "EX: x1 <= 15; IF: fetch instr 1"),
    (3,  "30ns", "00000008", "00000004", "100003b7", "lui x7, 0x10000",   "10000000", "00000000", 0, 0, 0, 0, 1, "EX: x7 <= 0x1000_0000; IF: fetch instr 2"),
    (4,  "40ns", "0000000c", "00000008", "0013a023", "sw x1, 0(x7)",      "10000000", "10000000", 0, 1, 0, 0, 0, "EX: MEM[0x1000_0000] <= x1; IF: fetch instr 3"),
    (5,  "50ns", "00000010", "0000000c", "0003a403", "lw x8, 0(x7)",      "10000000", "10000000", 1, 0, 0, 0, 1, "EX: Load requested; MEM returns 15"),
    (6,  "60ns", "00000010", "0000000c", "0003a403", "lw x8, 0(x7) [STALL]","10000000","10000000", 1, 0, 1, 0, 0, "dmem_ready=0 stall injected; PC & EX hold"),
    (7,  "70ns", "00000014", "00000010", "00808463", "beq x1, x8, +8",   "00000000", "00000000", 0, 0, 0, 0, 0, "dmem_ready=1 -> x8 <= 15; BEQ evaluated: taken!"),
    (8,  "80ns", "00000018", "00000018", "00000013", "BUBBLE (flush)",    "00000000", "00000000", 0, 0, 0, 0, 0, "Branch penalty bubble; PC redirected to target"),
    (9,  "90ns", "0000001c", "00000018", "0de00493", "addi x9, x0, 222", "000000de", "00000000", 0, 0, 0, 0, 1, "Target executed: x9 <= 222; IF fetch next"),
    (10, "100ns","00000020", "0000001c", "0000006f", "HALT",              "00000000", "00000000", 0, 0, 0, 1, 0, "HALT executed: halt=1 asserted; CPU stops")
]

def generate_timing_table(output_path):
    with open(output_path, "w") as f:
        f.write("=" * 110 + "\n")
        f.write(" Project 9 Member 4 (M4) CPU Core Timing and Pipeline Execution Table\n")
        f.write("=" * 110 + "\n")
        headers = ["Cyc", "Time", "PC (IF)", "EX PC", "Instruction Executing", "ALU Out", "DMem Addr", "R/W", "Stall", "Halt", "Note"]
        f.write(f"{headers[0]:<4} {headers[1]:<6} {headers[2]:<10} {headers[3]:<10} {headers[4]:<26} {headers[5]:<10} {headers[6]:<10} {headers[7]:<5} {headers[8]:<6} {headers[9]:<5} {headers[10]}\n")
        f.write("-" * 110 + "\n")
        for c in CYCLES_DATA:
            rw_str = "R" if c[8] else ("W" if c[9] else "-")
            f.write(f"{c[0]:<4} {c[1]:<6} 0x{c[2]:<8} 0x{c[3]:<8} {c[5]:<26} 0x{c[6]:<8} 0x{c[7]:<8} {rw_str:<5} {c[10]:<6} {c[11]:<5} {c[13]}\n")
        f.write("=" * 110 + "\n")
    print(f"Generated timing table: {output_path}")

def generate_svg(output_path):
    width = 1100
    height = 540
    margin_l = 180
    margin_t = 60
    cycle_w = 85
    row_h = 36

    signals = [
        ("CLK", "clk"),
        ("PC (Fetch)", "pc"),
        ("EX Instr", "instr"),
        ("ALU Result", "alu"),
        ("DMem Addr", "daddr"),
        ("DMem RE", "dre"),
        ("DMem WE", "dwe"),
        ("Stall", "stall"),
        ("RF WE", "rfwe"),
        ("Halt", "halt"),
    ]

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">')
    svg.append('<rect width="100%" height="100%" fill="#0f172a" rx="10"/>')

    # Title
    svg.append('<text x="30" y="38" fill="#38bdf8" font-family="monospace" font-size="20" font-weight="bold">M4 CPU Core — 2-Stage Pipeline Execution &amp; Stall Waveform</text>')

    # Grid vertical lines
    for i in range(11):
        x = margin_l + i * cycle_w
        svg.append(f'<line x1="{x}" y1="{margin_t}" x2="{x}" y2="{margin_t + len(signals)*row_h}" stroke="#334155" stroke-dasharray="3,3" stroke-width="1"/>')
        if i < 10:
            svg.append(f'<text x="{x + cycle_w/2}" y="{margin_t - 10}" fill="#94a3b8" font-family="monospace" font-size="12" text-anchor="middle">Cycle {i+1}</text>')

    # Signal labels
    for s_idx, (label, _) in enumerate(signals):
        y = margin_t + s_idx * row_h + 24
        svg.append(f'<text x="{margin_l - 15}" y="{y}" fill="#e2e8f0" font-family="monospace" font-size="13" font-weight="bold" text-anchor="end">{label}</text>')

    # Waveform rendering per signal
    # 1. CLK
    y_clk_top = margin_t + 6
    y_clk_bot = margin_t + row_h - 6
    clk_path = []
    for i in range(10):
        x0 = margin_l + i * cycle_w
        x_mid = x0 + cycle_w / 2
        x1 = x0 + cycle_w
        if i == 0:
            clk_path.append(f"M {x0} {y_clk_bot}")
        clk_path.append(f"L {x0} {y_clk_top} L {x_mid} {y_clk_top} L {x_mid} {y_clk_bot} L {x1} {y_clk_bot}")
    svg.append(f'<path d="{" ".join(clk_path)}" fill="none" stroke="#38bdf8" stroke-width="2"/>')

    # Helper for bus text boxes
    def draw_bus(row_idx, cyc_idx, text, color="#22d3ee", fill="#1e293b", text_col="#f8fafc"):
        y_top = margin_t + row_idx * row_h + 4
        h = row_h - 8
        x0 = margin_l + cyc_idx * cycle_w + 3
        w = cycle_w - 6
        svg.append(f'<rect x="{x0}" y="{y_top}" width="{w}" height="{h}" rx="4" fill="{fill}" stroke="{color}" stroke-width="1.5"/>')
        # Truncate text if needed
        disp = text if len(text) <= 10 else text[:9] + "…"
        svg.append(f'<text x="{x0 + w/2}" y="{y_top + h/2 + 4}" fill="{text_col}" font-family="monospace" font-size="10" text-anchor="middle">{disp}</text>')

    # Helper for binary signals
    def draw_binary(row_idx, vals, color="#a855f7"):
        y_high = margin_t + row_idx * row_h + 6
        y_low  = margin_t + row_idx * row_h + row_h - 6
        path = []
        for i, val in enumerate(vals):
            x0 = margin_l + i * cycle_w
            x1 = x0 + cycle_w
            y = y_high if val else y_low
            if i == 0:
                path.append(f"M {x0} {y}")
            else:
                prev_y = y_high if vals[i-1] else y_low
                if prev_y != y:
                    path.append(f"L {x0} {y}")
            path.append(f"L {x1} {y}")
        svg.append(f'<path d="{" ".join(path)}" fill="none" stroke="{color}" stroke-width="2"/>')

    # Row 1: PC
    for i, c in enumerate(CYCLES_DATA):
        draw_bus(1, i, "0x" + c[2][-4:], "#38bdf8", "#0f2744", "#bae6fd")

    # Row 2: EX Instr
    for i, c in enumerate(CYCLES_DATA):
        col = "#f43f5e" if "STALL" in c[5] or "BUBBLE" in c[5] else ("#eab308" if "HALT" in c[5] else "#34d399")
        bg  = "#3a131a" if "STALL" in c[5] or "BUBBLE" in c[5] else ("#3b2d07" if "HALT" in c[5] else "#063024")
        draw_bus(2, i, c[5].split()[0], col, bg, "#f0fdf4")

    # Row 3: ALU Result
    for i, c in enumerate(CYCLES_DATA):
        draw_bus(3, i, c[6], "#818cf8", "#1e1b4b", "#e0e7ff")

    # Row 4: DMem Addr
    for i, c in enumerate(CYCLES_DATA):
        draw_bus(4, i, "0x" + c[7][-4:], "#c084fc", "#2e1065", "#f3e8ff")

    # Binary signals:
    # Row 5: DMem RE
    draw_binary(5, [c[8] for c in CYCLES_DATA], "#2dd4bf")
    # Row 6: DMem WE
    draw_binary(6, [c[9] for c in CYCLES_DATA], "#fbbf24")
    # Row 7: Stall
    draw_binary(7, [c[10] for c in CYCLES_DATA], "#f43f5e")
    # Row 8: RF WE
    draw_binary(8, [c[12] for c in CYCLES_DATA], "#4ade80")
    # Row 9: Halt
    draw_binary(9, [c[11] for c in CYCLES_DATA], "#fb7185")

    # Legend / Annotation footer
    svg.append(f'<rect x="30" y="{margin_t + len(signals)*row_h + 15}" width="{width - 60}" height="75" rx="6" fill="#1e293b" stroke="#475569" stroke-width="1"/>')
    svg.append(f'<text x="50" y="{margin_t + len(signals)*row_h + 38}" fill="#94a3b8" font-family="monospace" font-size="11">Cycle 6: Injected dmem_ready=0 stall. PC and EX stage hold stable; memory request maintained without glitch.</text>')
    svg.append(f'<text x="50" y="{margin_t + len(signals)*row_h + 56}" fill="#94a3b8" font-family="monospace" font-size="11">Cycle 7-8: BEQ condition satisfied (taken). PC redirected to target (0x18); 1-cycle bubble inserted in EX.</text>')
    svg.append(f'<text x="50" y="{margin_t + len(signals)*row_h + 74}" fill="#94a3b8" font-family="monospace" font-size="11">Cycle 10: HALT instruction executed. Core asserts halt=1, halts pipeline, and drops imem_req.</text>')

    svg.append('</svg>')

    with open(output_path, "w") as f:
        f.write("\n".join(svg))
    print(f"Generated SVG waveform: {output_path}")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    tbl_path = os.path.join(script_dir, "m4_timing_table.txt")
    svg_path = os.path.join(script_dir, "m4_pipeline_waveform.svg")
    generate_timing_table(tbl_path)
    generate_svg(svg_path)
