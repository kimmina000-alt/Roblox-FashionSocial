"""Standing-still stretches of each clip's dancer (D-863 rule: hips and both
ankles under 0.12 body heights a second for 0.6 s or more).
Usage: python still_from_video.py <centercut dir>
Prints, per clip, stretches in clip seconds (= piece seconds)."""
import json
import sys

import numpy as np

d = sys.argv[1]
tr = json.load(open(d + "/tracks.json", encoding="utf-8"))
fps = tr["meta"]["fps"]
frames = tr["frames"]
clips = json.load(open(d + "/clips.json", encoding="utf-8"))

def series(ids, f0, f1):
    pts, hs = [], []
    last = None
    for f in range(f0, f1):
        best = None
        for p in frames[f] if f < len(frames) else []:
            if p["id"] in ids:
                best = p
        if best is None:
            pts.append(None)
            continue
        kp = np.array(best["kp"])
        hip = (kp[11, :2] + kp[12, :2]) / 2
        pts.append(np.concatenate([hip, kp[15, :2], kp[16, :2]]))
        hs.append(best["box"][3] - best["box"][1])
    # fill gaps
    arr = np.array([p if p is not None else [np.nan] * 6 for p in pts], dtype=float)
    for c in range(6):
        col = arr[:, c]
        ok = ~np.isnan(col)
        if ok.sum() > 1:
            arr[:, c] = np.interp(np.arange(len(col)), np.flatnonzero(ok), col[ok])
    return arr, (np.median(hs) if hs else 1.0)

for name, c in sorted(clips.items(), key=lambda kv: kv[1]["span"][0]):
    s, e = c["span"]
    f0, f1 = int(round(s * fps)), int(round(e * fps))
    arr, H = series(set(c["ids"]), f0, f1)
    # smooth over 0.2 s, speed in body heights / s
    k = int(fps * 0.2)
    ker = np.ones(k) / k
    sm = np.stack([np.convolve(arr[:, i], ker, mode="same") for i in range(6)], 1)
    v = np.zeros(len(sm))
    v[1:] = np.max(np.stack([np.hypot(*(sm[1:, j:j + 2] - sm[:-1, j:j + 2]).T) for j in (0, 2, 4)], 1), 1) * fps / H
    still = v < 0.12
    out, i = [], 0
    while i < len(still):
        if still[i]:
            j = i
            while j < len(still) and still[j]:
                j += 1
            if (j - i) / fps >= 0.6:
                out.append((round(i / fps, 2), round(j / fps, 2)))
            i = j
        else:
            i += 1
    print(name, f"{s:.2f}-{e:.2f}", json.dumps(out))
