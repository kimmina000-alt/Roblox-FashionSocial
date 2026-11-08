"""Hand tiles with the capture's hand drawn on them, to spot wrist bends the capture missed (D-1054).

python overlay_sheet.py <yolo pose .pt> <clip dir> <out dir> <capture json> [step = 0.25]

capture json: {"5.mp4": "<len>|<L R>|<L R>|..."} from Studio's _G.capBend (each side
"forearm angle/bend" in picture degrees or "-"). Per tile (the dancer's own left
hand blue frame, right hand red): the video round the wrist, the video forearm
(yellow), and from the wrist the way the capture's hand points against that
forearm (green, its bend in the corner). A hand clearly off the green line is a
wrist bend the capture missed.
"""
import sys, math, json
from pathlib import Path
import numpy as np, cv2
from ultralytics import YOLO

pose = YOLO(sys.argv[1])
clipdir = Path(sys.argv[2]); outdir = Path(sys.argv[3]); outdir.mkdir(parents=True, exist_ok=True)
capj = json.load(open(sys.argv[4], encoding="utf-8"))
step = float(sys.argv[5]) if len(sys.argv) > 5 else 0.25
T, COLS = 120, 8

for name, capstr in capj.items():
    caps = capstr.split("|")[1:]
    cap = cv2.VideoCapture(str(clipdir / name)); fps = cap.get(5) or 30
    w = cap.get(3); h = cap.get(4)
    tiles = []; prev = None; f = 0; nxt = 0.0; k = 0
    while True:
        ok, img = cap.read()
        if not ok: break
        t = f / fps; f += 1
        if t + 1e-6 < nxt: continue
        nxt += step
        cs = caps[k].split(" ") if k < len(caps) else ["-", "-"]; k += 1
        r = pose.predict(img, verbose=False, conf=0.3)[0]
        best = None
        for i in range(len(r.boxes)):
            x1, y1, x2, y2 = r.boxes.xyxy[i].tolist(); cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            ref = prev or (w / 2, h / 2)
            s = (x2 - x1) * (y2 - y1) / (1 + math.hypot(cx - ref[0], cy - ref[1]) / w * 8)
            if best is None or s > best[0]: best = (s, i, cx, cy)
        pair = []
        for side, (ei, wi) in enumerate([(7, 9), (8, 10)]):
            tile = np.full((T, T, 3), 40, np.uint8)
            label = ""
            if best:
                kp = r.keypoints.data[best[1]].tolist()
                el, wr = kp[ei], kp[wi]
                L = max(math.hypot(wr[0] - el[0], wr[1] - el[1]), 30)
                s = L * 0.8
                x0, y0 = int(wr[0] - s), int(wr[1] - s)
                pad = cv2.copyMakeBorder(img, 400, 400, 400, 400, cv2.BORDER_CONSTANT, value=(40, 40, 40))
                crop = pad[y0 + 400:y0 + 400 + int(2 * s), x0 + 400:x0 + 400 + int(2 * s)].copy()
                if crop.size:
                    sc = T / crop.shape[0]
                    tile = cv2.resize(crop, (T, T))
                    wx, wy = (wr[0] - x0) * sc, (wr[1] - y0) * sc
                    cv2.line(tile, (int((el[0] - x0) * sc), int((el[1] - y0) * sc)), (int(wx), int(wy)), (0, 255, 255), 1)
                    c = cs[side] if side < len(cs) else "-"
                    if c != "-" and min(el[2], wr[2]) > 0.5:
                        bend = float(c.split("/")[1])
                        a = math.atan2(wr[1] - el[1], wr[0] - el[0]) + math.radians(bend)
                        cv2.line(tile, (int(wx), int(wy)), (int(wx + math.cos(a) * 34), int(wy + math.sin(a) * 34)), (0, 255, 0), 2)
                        label = "%d" % bend
            cv2.rectangle(tile, (0, 0), (T - 1, T - 1), (255, 80, 0) if side == 0 else (0, 0, 255), 3)
            if label:
                cv2.putText(tile, label, (T - 40, T - 8), 0, 0.45, (0, 0, 0), 3); cv2.putText(tile, label, (T - 40, T - 8), 0, 0.45, (0, 255, 0), 1)
            pair.append(tile)
        if best: prev = (best[2], best[3])
        lab = np.hstack(pair)
        cv2.putText(lab, "%.2f" % t, (4, 16), 0, 0.5, (0, 0, 0), 3); cv2.putText(lab, "%.2f" % t, (4, 16), 0, 0.5, (255, 255, 255), 1)
        tiles.append(lab)
    rows = []
    for i in range(0, len(tiles), COLS):
        row = tiles[i:i + COLS]
        while len(row) < COLS: row.append(np.zeros_like(tiles[0]))
        rows.append(np.hstack(row))
    sheet = np.vstack(rows)
    cv2.putText(sheet, name, (sheet.shape[1] - 120, sheet.shape[0] - 8), 0, 0.7, (0, 255, 0), 2)
    cv2.imwrite(str(outdir / (Path(name).stem + ".jpg")), sheet, [cv2.IMWRITE_JPEG_QUALITY, 85])
    print(name, len(tiles), flush=True)
