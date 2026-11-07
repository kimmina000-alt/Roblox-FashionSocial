import sys, json, math
from pathlib import Path
from ultralytics import YOLO
import cv2
model = YOLO(sys.argv[1])
clipdir = Path(sys.argv[2]); out_path = sys.argv[3]
names = sys.argv[4].split(",")
res = {}
for name in names:
    p = clipdir / name
    if not p.exists(): continue
    cap = cv2.VideoCapture(str(p)); fps = cap.get(cv2.CAP_PROP_FPS) or 30
    w = cap.get(cv2.CAP_PROP_FRAME_WIDTH); h = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
    rows = []; f = 0
    while True:
        ok, img = cap.read()
        if not ok: break
        if f % 3 == 0:
            r = model.predict(img, verbose=False, conf=0.3)[0]
            best = None
            if r.keypoints is not None and len(r.boxes) > 0:
                for i in range(len(r.boxes)):
                    x1, y1, x2, y2 = r.boxes.xyxy[i].tolist()
                    cx = (x1 + x2) / 2; area = (x2 - x1) * (y2 - y1)
                    score = area / (1 + abs(cx - w / 2) / w * 6)
                    if best is None or score > best[0]: best = (score, i)
            if best:
                kp = r.keypoints.data[best[1]].tolist()
                ls, rs, lh, rh, nose = kp[5], kp[6], kp[11], kp[12], kp[0]
                if min(ls[2], rs[2], lh[2], rh[2]) > 0.5:
                    mx, my = (ls[0] + rs[0]) / 2, (ls[1] + rs[1]) / 2
                    hx, hy = (lh[0] + rh[0]) / 2, (lh[1] + rh[1]) / 2
                    th = math.hypot(mx - hx, my - hy)
                    if th > 10:
                        rows.append([round(f / fps, 3), round((ls[0] - rs[0]) / th, 3), round(nose[2], 2), round((nose[0] - mx) / th, 3)])
        f += 1
    res[name] = {"fps": fps, "rows": rows}
    print(name, len(rows), flush=True)
    json.dump(res, open(out_path, "w"))
print("done")
