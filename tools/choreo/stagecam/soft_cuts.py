"""Second pass: soft cuts (blur whips / quick dissolves) inside shots.
Histogram distance between frame i and i-4 (0.13 s) on a 3x3 grid (so a
layout change counts even with the same colours)."""
import json
import subprocess
import sys

import numpy as np

video, out = sys.argv[1], sys.argv[2]
W, H, FPS = 96, 54, 30
raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", "12", "-to", "166", "-i", video, "-vf", f"fps={FPS},scale={W}:{H}",
                      "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
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
OFF = 12.0
cuts = json.load(open(out + r"\cuts.json"))["cuts"]
hard = [c - OFF for c in cuts if 12.2 < c < 165.6]
res = []
for i in range(L, n - L):
    if d[i] == d[max(0, i - 6):i + 7].max() and d[i] > 0.45:
        t = i / FPS - L / 2 / FPS
        if all(abs(t - h) > 0.35 for h in hard):
            res.append((round(t + OFF - 12.15, 2), round(float(d[i]), 2)))
print(res)
json.dump(res, open(out + r"\soft_cuts.json", "w"))
