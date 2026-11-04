"""Per-shot analysis of a stage video.
python shots.py video.mp4 cuts.json out_dir song_start song_end offset model.pt
For each shot inside [song_start, song_end] (video seconds): YOLO pose of
people (size of the biggest person, how many, visible body parts), global
camera motion between frames (ORB + RANSAC similarity: zoom, pan x/y, roll),
and the progress curve of the motion (for easing). Writes shots.json and a
contact sheet per 20 shots (start / mid / end frame).
"""
import json
import os
import sys

import cv2
import numpy as np
from ultralytics import YOLO

video, cutsf, out = sys.argv[1], sys.argv[2], sys.argv[3]
t0, t1, OFF = float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
model = YOLO(sys.argv[7])
cuts = json.load(open(cutsf))["cuts"]
bounds = [t0] + [c for c in cuts if t0 + 0.2 < c < t1 - 0.2] + [t1]
cap = cv2.VideoCapture(video)
FPS = cap.get(cv2.CAP_PROP_FPS)
W, H = int(cap.get(3)), int(cap.get(4))
orb = cv2.ORB_create(1500)
bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)


# read the whole song part once, in order, 10 frames a second (half size)
STORE = {}
cap.set(cv2.CAP_PROP_POS_FRAMES, int(t0 * FPS) - 2)
fi = int(t0 * FPS) - 2
every = max(1, int(round(FPS / 10)))
while True:
    ok, f = cap.read()
    if not ok or fi / FPS > t1 + 0.2:
        break
    if fi % every == 0:
        STORE[fi] = cv2.resize(f, (480, 270))
    fi += 1
W, H = 480, 270
KEYS = np.array(sorted(STORE))
print("frames", len(KEYS), flush=True)


def frame_at(t):
    k = KEYS[np.argmin(np.abs(KEYS - t * FPS))]
    return STORE[int(k)]


def people(f):
    r = model(f, verbose=False, conf=0.35)[0]
    res = []
    if r.boxes is None:
        return res
    for b, k in zip(r.boxes.xyxy.cpu().numpy(), r.keypoints.data.cpu().numpy()):
        x0, y0, x1, y1 = b
        vis = k[:, 2] > 0.5
        res.append({"h": (y1 - y0) / H, "cx": (x0 + x1) / 2 / W, "cy": (y0 + y1) / 2 / H, "top": y0 / H,
                    "head": bool(vis[0:5].any()), "hip": bool(vis[11:13].any()), "knee": bool(vis[13:15].any()),
                    "ankle": bool(vis[15:17].any()), "eye_y": float(k[1:3, 1].mean() / H) if vis[1:3].all() else None})
    return res


def motion(a, b):
    ga, gb = cv2.cvtColor(a, cv2.COLOR_BGR2GRAY), cv2.cvtColor(b, cv2.COLOR_BGR2GRAY)
    ka, da = orb.detectAndCompute(ga, None)
    kb, db = orb.detectAndCompute(gb, None)
    if da is None or db is None or len(ka) < 20 or len(kb) < 20:
        return None
    m = bf.match(da, db)
    if len(m) < 20:
        return None
    pa = np.float32([ka[x.queryIdx].pt for x in m])
    pb = np.float32([kb[x.trainIdx].pt for x in m])
    M, inl = cv2.estimateAffinePartial2D(pa, pb, method=cv2.RANSAC, ransacReprojThreshold=3)
    if M is None or inl.sum() < 15:
        return None
    s = float(np.hypot(M[0, 0], M[1, 0]))
    rot = float(np.degrees(np.arctan2(M[1, 0], M[0, 0])))
    # translation of the frame centre
    c = np.array([W / 2, H / 2])
    nc = M[:, :2] @ c + M[:, 2]
    d = (nc - c)
    return s, d[0] / W, d[1] / H, rot, int(inl.sum())


shots = []
for i in range(len(bounds) - 1):
    a, b = bounds[i], bounds[i + 1]
    dt = 0.1
    ts = np.arange(a + 0.04, b - 0.04, dt)
    if len(ts) < 2:
        ts = np.array([a + 0.02, b - 0.02])
    frames = [frame_at(t) for t in ts]
    zoom, px, py, roll = [1.0], [0.0], [0.0], [0.0]
    for f0, f1 in zip(frames, frames[1:]):
        r = motion(f0, f1) if f0 is not None and f1 is not None else None
        if r is None:
            r = (1.0, 0.0, 0.0, 0.0, 0)
        zoom.append(zoom[-1] * r[0]); px.append(px[-1] + r[1]); py.append(py[-1] + r[2]); roll.append(roll[-1] + r[3])
    samp = [0, len(frames) // 2, len(frames) - 1]
    pp = []
    for j in samp:
        ps = people(frames[j]) if frames[j] is not None else []
        ps.sort(key=lambda p: -p["h"])
        pp.append({"n": len(ps), "top": ps[:3]})
    # progress of the dominant motion (for easing)
    zl = np.log(np.array(zoom)); pxs = np.array(px); pys = np.array(py)
    mag = np.abs(zl) + np.hypot(pxs, pys)
    total = np.hypot(np.hypot(pxs[-1], pys[-1]), zl[-1])
    path = np.r_[0, np.cumsum(np.hypot(np.hypot(np.diff(pxs), np.diff(pys)), np.diff(zl)))]
    prog = (path / path[-1]).tolist() if path[-1] > 1e-6 else []
    q = [round(float(np.interp(x, np.linspace(0, 1, len(prog)), prog)), 2) for x in (0.25, 0.5, 0.75)] if prog else []
    shots.append({"i": i + 1, "v0": round(a, 2), "v1": round(b, 2), "s0": round(a - OFF, 2), "s1": round(b - OFF, 2),
                  "dur": round(b - a, 2), "zoom": round(float(zoom[-1]), 3), "panx": round(float(pxs[-1]), 3),
                  "pany": round(float(pys[-1]), 3), "roll": round(float(roll[-1]), 2), "path": round(float(path[-1]), 3),
                  "prog": q, "people": pp})
    for k, j in enumerate(samp):
        if frames[j] is not None:
            cv2.imwrite(os.path.join(out, "shots", f"{i + 1:03d}_{k}.jpg"), cv2.resize(frames[j], (320, 180)))
    print(i + 1, a, b, shots[-1]["zoom"], shots[-1]["panx"], shots[-1]["pany"], flush=True)
json.dump(shots, open(os.path.join(out, "shots.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False, default=float)

# contact sheets: one row per shot (start, mid, end) + label
rows = []
for s in shots:
    ims = []
    for k in range(3):
        p = os.path.join(out, "shots", f"{s['i']:03d}_{k}.jpg")
        im = cv2.imread(p) if os.path.exists(p) else np.zeros((180, 320, 3), np.uint8)
        ims.append(im)
    row = np.hstack(ims)
    cv2.rectangle(row, (0, 0), (300, 26), (0, 0, 0), -1)
    cv2.putText(row, f"#{s['i']} {s['s0']:.1f}-{s['s1']:.1f} z{s['zoom']:.2f}", (4, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.55,
                (255, 255, 255), 1)
    rows.append(row)
for k in range(0, len(rows), 8):
    cv2.imwrite(os.path.join(out, f"sheet_shots_{k // 8 + 1:02d}.jpg"), np.vstack(rows[k:k + 8]))
