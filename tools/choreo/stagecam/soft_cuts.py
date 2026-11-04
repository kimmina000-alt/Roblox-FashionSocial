"""Second pass: soft cuts (blur whips / quick dissolves) inside shots.
Histogram distance between frame i and i-4 (0.13 s) on a 3x3 grid (so a
layout change counts even with the same colours). Many peaks are fast camera
moves or light flashes: check them by eye (strips.py).

python soft_cuts.py <video> <out_dir with cuts.json> <offset> <song_end>
  offset = video time - song time (align_wide.py); song_end in song seconds.
Prints (song time, score) of peaks that are not near a hard cut.
"""
import json
import os
import subprocess
import sys

import numpy as np

video, out = sys.argv[1], sys.argv[2]
OFF, END = float(sys.argv[3]), float(sys.argv[4])
start = max(OFF - 0.2, 0)
W, H, FPS = 96, 54, 30
raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{start}", "-to", f"{OFF + END + 0.2}", "-i", video, "-vf",
                      f"fps={FPS},scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                     capture_output=True, check=True).stdout
f = np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)
n = len(f)
feat = []
for fr in f:
    v = []
    for gy in range(3):
        for gx in range(3):
            c = fr[gy * 18:(gy + 1) * 18, gx * 32:(gx + 1) * 32]
            for ch in range(3):
                v.append(np.histogram(c[..., ch], bins=8, range=(0, 256))[0] / c[..., ch].size)
    feat.append(np.concatenate(v))
feat = np.array(feat)
L = 4
d = np.r_[np.zeros(L), np.abs(feat[L:] - feat[:-L]).sum(1) / 27]
cuts = json.load(open(os.path.join(out, "cuts.json")))["cuts"]
hard = [c for c in cuts]
res = []
for i in range(L, n - L):
    if d[i] == d[max(0, i - 6):i + 7].max() and d[i] > 0.45:
        tv = start + i / FPS - L / 2 / FPS  # video time
        if all(abs(tv - h) > 0.35 for h in hard):
            res.append((round(tv - OFF, 2), round(float(d[i]), 2)))
print(res)
json.dump(res, open(os.path.join(out, "soft_cuts.json"), "w"))
