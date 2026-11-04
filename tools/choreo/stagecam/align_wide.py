"""Coarse + windowed song->video offset over a wide lag range.
python -I coarse.py loud.txt video.mp4 lagmin lagmax
"""
import subprocess
import sys

import numpy as np

lines = open(sys.argv[1], encoding="utf-8").read().strip().splitlines()
step = float(lines[0].split()[1])
s = np.array([float(x) if x else np.nan for x in lines[1].split(",")])
i = np.arange(len(s)); ok = ~np.isnan(s); s = np.interp(i, i[ok], s[ok])
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", sys.argv[2], "-vn", "-ac", "1", "-ar", "8000", "-f", "s16le", "-"],
                     capture_output=True, check=True).stdout
a = np.frombuffer(raw, np.int16).astype(float); n = int(8000 * step); m = len(a) // n
e = np.sqrt((a[: m * n].reshape(m, n) ** 2).mean(1))
lo, hi = float(sys.argv[3]), float(sys.argv[4])
ts, tv = np.arange(len(s)) * step, np.arange(len(e)) * step


def onset(x):
    d = np.diff(np.log1p(x), prepend=np.log1p(x[0])); d[d < 0] = 0; return d


def lev(x):
    return np.log1p(x)


for name, f in (("level", lev), ("onset", onset)):
    S, E = f(s), f(e)
    best = []
    for lag in np.arange(lo, hi, step):
        g = ts[(ts + lag >= 0) & (ts + lag < tv[-1])]
        sg = np.interp(g, ts, S); vg = np.interp(g + lag, tv, E)
        sg = (sg - sg.mean()) / sg.std(); vg = (vg - vg.mean()) / vg.std()
        best.append(((sg * vg).mean(), lag))
    best.sort(reverse=True)
    print(name, "global:", " ".join(f"{l:+.2f}({r:.3f})" for r, l in best[:5]))
# windowed around the global best
base = best[0][1]
print("windows (onset, +-2 s around", round(base, 2), ")")
S, E = onset(s), onset(e)
res = []
for c in np.arange(10, ts[-1] - 10, 10):
    g = np.arange(c - 10, c + 10, step)
    sg = np.interp(g, ts, S); sg = (sg - sg.mean()) / (sg.std() + 1e-9)
    r = []
    for lag in np.arange(base - 2, base + 2, step / 2):
        vg = np.interp(g + lag, tv, E); vg = (vg - vg.mean()) / (vg.std() + 1e-9)
        r.append(((sg * vg).mean(), lag))
    r.sort(reverse=True)
    res.append((c, r[0][1], r[0][0]))
    print(f"  song {c:5.0f}: {r[0][1]:+.3f} ({r[0][0]:.2f})  2nd {r[1][1]:+.3f}")
c, o, q = np.array(res).T
k = q > 0.25
print("median", np.median(o[k]), "fit", np.polyfit(c[k], o[k], 1))
