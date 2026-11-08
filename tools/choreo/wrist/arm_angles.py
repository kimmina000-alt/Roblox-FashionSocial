"""The followed dancer's forearms in the picture every `step` seconds (D-1054).

python arm_angles.py <yolo pose .pt> <clip> <step> -> one line: "len|L R|L R|..." where
each side is "forearm angle" (picture degrees, y down) or "-" when the elbow or
wrist is unsure; the same layout as Studio's _G.capBend, to compare the two.
"""
import sys, math
import cv2
from ultralytics import YOLO

pose = YOLO(sys.argv[1]); cap = cv2.VideoCapture(sys.argv[2]); step = float(sys.argv[3])
fps = cap.get(5) or 30; w, h = cap.get(3), cap.get(4)
out = []; prev = None; f = 0; nxt = 0.0
while True:
    ok, img = cap.read()
    if not ok: break
    t = f / fps; f += 1
    if t + 1e-6 < nxt: continue
    nxt += step
    r = pose.predict(img, verbose=False, conf=0.3)[0]
    best = None
    for i in range(len(r.boxes)):
        x1, y1, x2, y2 = r.boxes.xyxy[i].tolist(); cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        ref = prev or (w / 2, h / 2)
        s = (x2 - x1) * (y2 - y1) / (1 + math.hypot(cx - ref[0], cy - ref[1]) / w * 8)
        if best is None or s > best[0]: best = (s, i, cx, cy)
    row = []
    if best:
        prev = (best[2], best[3]); kp = r.keypoints.data[best[1]].tolist()
        for ei, wi in ((7, 9), (8, 10)):
            el, wr = kp[ei], kp[wi]
            L = math.hypot(wr[0] - el[0], wr[1] - el[1])
            row.append("%d" % math.degrees(math.atan2(wr[1] - el[1], wr[0] - el[0])) if min(el[2], wr[2]) > 0.5 and L > 15 else "-")
    else:
        row = ["-", "-"]
    out.append(" ".join(row))
print("%.2f|" % (f / fps) + "|".join(out))
