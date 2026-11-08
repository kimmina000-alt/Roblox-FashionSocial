"""Head tilts in the video, for Studio to compare with the capture (D-1054).

python head_video.py <yolo pose .pt> <clip dir> <clip names,comma> [step = 0.2] [min = 15]

Prints one line per clip, "name t=roll t=roll ...", only the samples where the
followed dancer faces the camera and tilts the head `min`+ degrees against the
shoulders (eye line right -> left against shoulder line right -> left, picture
degrees, y down; median of the frames within +-0.06 s of each sample). Studio's
_G.headMisses reads these lines.
"""
import sys, math, statistics as st
from pathlib import Path
import cv2
from ultralytics import YOLO

pose = YOLO(sys.argv[1]); clipdir = Path(sys.argv[2]); names = sys.argv[3].split(",")
step = float(sys.argv[4]) if len(sys.argv) > 4 else 0.2
MIN = float(sys.argv[5]) if len(sys.argv) > 5 else 15

def ang(a, b):
    return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))

for name in names:
    cap = cv2.VideoCapture(str(clipdir / name)); fps = cap.get(5) or 30
    w, h = cap.get(3), cap.get(4)
    vid = {}; prev = None; f = 0
    while True:
        ok, img = cap.read()
        if not ok: break
        t = f / fps; f += 1
        k = round(t / step)
        if abs(t - k * step) > 0.06: continue
        r = pose.predict(img, verbose=False, conf=0.3)[0]
        best = None
        for i in range(len(r.boxes)):
            x1, y1, x2, y2 = r.boxes.xyxy[i].tolist(); cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            ref = prev or (w / 2, h / 2)
            s = (x2 - x1) * (y2 - y1) / (1 + math.hypot(cx - ref[0], cy - ref[1]) / w * 8)
            if best is None or s > best[0]: best = (s, i, cx, cy)
        if not best: continue
        prev = (best[2], best[3])
        kp = r.keypoints.data[best[1]].tolist()
        le, re_, ls, rs = kp[1], kp[2], kp[5], kp[6]
        if min(le[2], re_[2], ls[2], rs[2]) < 0.6 or ls[0] - rs[0] < 20: continue
        vid.setdefault(k, []).append((ang(re_, le) - ang(rs, ls) + 180) % 360 - 180)
    parts = []
    for k in sorted(vid):
        v = st.median(vid[k])
        if abs(v) >= MIN: parts.append("%g=%d" % (round(k * step, 2), round(v)))
    print(name, " ".join(parts), flush=True)
