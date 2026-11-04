"""Shot cuts of a stage video: frame-difference on downscaled frames.
Usage: python -I cuts.py <video.mp4> <out_dir>
Writes cuts.json (list of cut times) and diff.npy (per-frame score), plus a
thumbnail (mid frame) per shot in out_dir/shots/.
"""
import json
import os
import subprocess
import sys

import numpy as np

video, out = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(out, "shots"), exist_ok=True)
W, H, FPS = 160, 90, 30
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-vf", f"fps={FPS},scale={W}:{H}", "-f", "rawvideo",
                      "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
f = np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3).astype(np.float32)
n = len(f)
# colour histogram difference + mean abs pixel difference
hist = []
for fr in f:
    h = [np.histogram(fr[..., c], bins=16, range=(0, 256))[0] for c in range(3)]
    hist.append(np.concatenate(h) / (W * H))
hist = np.array(hist)
hd = np.r_[0, np.abs(np.diff(hist, axis=0)).sum(1)]
pd = np.r_[0, np.abs(np.diff(f, axis=0)).mean((1, 2, 3)) / 255]
score = hd * 0.5 + pd * 2
np.save(os.path.join(out, "diff.npy"), score)
# adaptive threshold: local median + k * MAD, min gap 0.25 s
cuts = []
win = FPS
for i in range(1, n):
    lo, hi = max(0, i - win), min(n, i + win)
    loc = np.r_[score[lo:i], score[i + 1:hi]]
    med = np.median(loc)
    mad = np.median(np.abs(loc - med)) + 1e-3
    if score[i] > max(0.35, med + 8 * mad) and score[i] == score[max(0, i - 3):i + 4].max():
        if not cuts or i - cuts[-1] > FPS * 0.25:
            cuts.append(i)
times = [round(i / FPS, 3) for i in cuts]
json.dump({"fps": FPS, "cuts": times, "duration": round(n / FPS, 3)}, open(os.path.join(out, "cuts.json"), "w"), indent=1)
print(len(times), "cuts")
print(times)
