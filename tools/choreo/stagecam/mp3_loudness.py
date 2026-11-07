"""Loudness record of an audio file in the record_loudness.lua format
("bin 0.10" + comma list), for align_wide.py when Studio cannot record the
game song (D-939). Only valid when the upload runs on the original song's
clock (fileSpeed 3 uploads made from that file); check it first by lining the
file up with the practice video and comparing with the choreography offset.

python mp3_loudness.py <audio file> <out.txt> [bin seconds]
"""
import subprocess
import sys

import numpy as np

src, out = sys.argv[1], sys.argv[2]
step = float(sys.argv[3]) if len(sys.argv) > 3 else 0.1
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-vn", "-ac", "1", "-ar", "8000", "-f", "s16le", "-"],
                     capture_output=True, check=True).stdout
a = np.frombuffer(raw, np.int16).astype(float)
n = int(8000 * step)
m = len(a) // n
e = np.sqrt((a[: m * n].reshape(m, n) ** 2).mean(1)) / 300.0
with open(out, "w", encoding="utf-8") as f:
    f.write(f"bin {step:.2f}\n" + ",".join(f"{v:.0f}" for v in e) + "\n")
print(out, m, "bins")
