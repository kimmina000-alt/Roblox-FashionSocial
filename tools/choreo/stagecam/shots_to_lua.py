"""Shot list in song seconds from shots.py output (D-939): each shot's size
from the pose of its biggest dancer (ankles seen = full/wide/xwide by height,
knees = knee, hips = waist, else bust), a push-in / pull-out over the shot
becomes `to`, a strong pan becomes a small yaw, wides get a crane pitch.

python shots_to_lua.py <shots.json> <a> <b> <song end> > block.txt
song time = (video time - b) / a   (a = 1 for an upload on the song clock)
Very short flashes (< 0.35 s) are left out. Prints cutList rows.
"""
import json
import sys

S = json.load(open(sys.argv[1], encoding="utf-8"))
a, b, end = float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
ORDER = ["close", "bust", "waist", "knee", "full", "wide", "xwide"]


def size_of(p):
    # p = one of the shot's three sample frames; its top = the biggest dancer
    if not p["top"]:
        return None
    best = p["top"][0]
    h = best["h"]
    if best["ankle"]:
        return "full" if h >= 0.6 else "wide" if h >= 0.3 else "xwide"
    if best["knee"]:
        return "knee"
    if best["hip"]:
        return "waist"
    return "bust"


# a soft cut inside a detected shot shows as sample frames of other sizes:
# split the shot there (just before that sample)
parts = []
for s in S:
    if s["dur"] < 0.35:
        continue
    sizes = [size_of(p) for p in s["people"]]
    progs = s["prog"] or [0.5]
    first = next((z for z in sizes if z), None) or "wide"
    pieces = [(s["v0"], first)]
    for k in range(1, min(len(sizes), len(progs))):
        z = sizes[k]
        if z and z != pieces[-1][1] and s["dur"] * (progs[k] - progs[k - 1]) > 0.6:
            pieces.append((s["v0"] + s["dur"] * (progs[k - 1] + progs[k]) / 2, z))
    for j, (v, z) in enumerate(pieces):
        parts.append((v, z, s if len(pieces) == 1 else None))

rows, last = [], None
for v, size, s in parts:
    t = round((v - b) / a, 2)
    if t >= end:
        break
    s = s or {"panx": 0, "zoom": 1}
    yaw = 0
    if abs(s["panx"]) > 0.15:
        yaw = max(-20, min(20, -round(s["panx"] * 30 / 5) * 5))
    pitch = 8 if size == "xwide" else 5 if size == "wide" else 0
    to = None
    i = ORDER.index(size)
    if s["zoom"] > 1.4 and i > 0:
        to = ORDER[i - 1]
    elif s["zoom"] < 0.7 and i < len(ORDER) - 1:
        to = ORDER[i + 1]
    row = (max(t, 0.0), size, yaw, pitch, to)
    if t <= 0.3:  # the shot on screen when the song starts
        row = (0.0,) + row[1:]
        rows = [row]
    elif last and last[1:] == row[1:]:
        continue
    else:
        rows.append(row)
    last = row

out = []
for t, size, yaw, pitch, to in rows:
    parts = [f"{t:.2f}".rstrip("0").rstrip(".") if t else "0", f'"{size}"']
    if yaw or pitch or to:
        parts.append(str(yaw))
    if pitch or to:
        parts.append(str(pitch))
    if to:
        parts.append(f'{{ size = "{to}" }}')
    out.append("{ " + ", ".join(parts) + " }")
line = "\t\t"
for o in out:
    if len(line) + len(o) > 110:
        print(line.rstrip())
        line = "\t\t"
    line += o + ", "
print(line.rstrip())
print(f"-- {len(out)} shots", file=sys.stderr)
