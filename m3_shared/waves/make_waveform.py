#!/usr/bin/env python3
"""
Project 9 - Member 3 (M3) waveform renderer.
Reads waves/conflict_log.txt (written by tb_shared_mem.v) and draws an SVG
timing diagram of the conflict window: fetch+load, fetch+store, 8 back-to-back
loads (fetch starves) and a 6-store burst, each followed by the delayed fetch.

Usage:  python3 waves/make_waveform.py [first_cycle] [last_cycle]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "conflict_log.txt")
OUT = os.path.join(HERE, "m3_conflict_waveform.svg")

first = int(sys.argv[1]) if len(sys.argv) > 1 else 214
last = int(sys.argv[2]) if len(sys.argv) > 2 else 244

rows = []
with open(LOG) as f:
    for line in f:
        parts = [p.strip() for p in line.split("|")]
        if len(parts) != 8 or not parts[0].isdigit():
            continue
        cyc = int(parts[0])
        if not first <= cyc <= last:
            continue
        ireq, iaddr = parts[2].split()
        re_, we_, daddr = parts[3].split()
        iready, dready = parts[4].split()
        irdata, drdata = parts[5].split()
        rows.append(dict(cycle=cyc, rst_n=parts[1], imem_req=ireq, imem_addr=iaddr,
                         dmem_re=re_, dmem_we=we_, dmem_addr=daddr,
                         imem_ready=iready, dmem_ready=dready, imem_rdata=irdata,
                         conflict=parts[6], conflict_count=parts[7]))

if not rows:
    sys.exit("no cycles found in range; run ./run_tests.sh first")

BITS = ["imem_req", "dmem_re", "dmem_we", "imem_ready", "dmem_ready", "conflict"]
BUSES = ["imem_addr", "dmem_addr", "imem_rdata", "conflict_count"]

CW, RH, LW, TOP = 34, 34, 130, 50
W = LW + CW * len(rows) + 20
H = TOP + RH * (len(BITS) + len(BUSES) + 1) + 30

svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
       f'font-family="Menlo,Consolas,monospace" font-size="11">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="10" y="22" font-size="14" font-weight="bold" fill="#111">'
       f'M3 shared memory: data access wins, fetch stalls (cycles {first}-{last})</text>']

# clock row + stall shading
y0 = TOP
svg.append(f'<text x="10" y="{y0 + 20}" fill="#333">clk / cycle</text>')
for i, r in enumerate(rows):
    x = LW + i * CW
    if r["conflict"] == "1":
        svg.append(f'<rect x="{x}" y="{TOP}" width="{CW}" height="{H - TOP - 30}" '
                   f'fill="#fde2e2" opacity="0.7"/>')
    svg.append(f'<path d="M{x},{y0 + 26} L{x},{y0 + 8} L{x + CW / 2},{y0 + 8} '
               f'L{x + CW / 2},{y0 + 26} L{x + CW},{y0 + 26}" stroke="#555" fill="none"/>')
    if i % 2 == 0:
        svg.append(f'<text x="{x + 2}" y="{y0 + 6}" font-size="9" fill="#777">{r["cycle"]}</text>')

y = TOP + RH
for name in BITS:
    svg.append(f'<text x="10" y="{y + 20}" fill="#111">{name}</text>')
    pts = []
    for i, r in enumerate(rows):
        x = LW + i * CW
        yy = y + 8 if r[name] == "1" else y + 26
        pts += [f"{x},{yy}", f"{x + CW},{yy}"]
    color = "#c62828" if name in ("conflict", "imem_ready") else "#1565c0"
    svg.append(f'<polyline points="{" ".join(pts)}" stroke="{color}" stroke-width="2" fill="none"/>')
    y += RH

for name in BUSES:
    svg.append(f'<text x="10" y="{y + 20}" fill="#111">{name}</text>')
    i = 0
    while i < len(rows):
        j = i
        while j + 1 < len(rows) and rows[j + 1][name] == rows[i][name]:
            j += 1
        x1, x2 = LW + i * CW, LW + (j + 1) * CW
        svg.append(f'<path d="M{x1},{y + 17} L{x1 + 4},{y + 8} L{x2 - 4},{y + 8} L{x2},{y + 17} '
                   f'L{x2 - 4},{y + 26} L{x1 + 4},{y + 26} Z" fill="#f1f8e9" stroke="#2e7d32"/>')
        val = rows[i][name]
        if name != "conflict_count":
            val = val.lstrip("0") or "0"
        if (x2 - x1) >= 30:
            svg.append(f'<text x="{x1 + 6}" y="{y + 21}" font-size="9" fill="#1b5e20">{val}</text>')
        i = j + 1
    y += RH

svg.append(f'<text x="{LW}" y="{H - 10}" font-size="10" fill="#c62828">'
           f'Shaded cycles = fetch delayed by a data access (conflict_count increments at the next edge)</text>')
svg.append("</svg>")

with open(OUT, "w") as f:
    f.write("\n".join(svg))
print(f"wrote {OUT} ({len(rows)} cycles)")
