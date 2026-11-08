"""Wrist bends in the video, for Studio to compare with the capture (D-1056).

python hand_video.py <yolo pose .pt> <hand_landmarker.task> <clip dir> <clip names,comma> [step = 0.2] [min = 25]

Prints one line per clip, "name L:t=bend R:t=bend ...": the followed dancer's own
left / right hand, the hand (wrist -> middle knuckle, MediaPipe hand landmarker
on a cut round YOLO's wrist) against the forearm (YOLO elbow -> wrist), signed
picture degrees (y down), only where
  - the hand shows clearly: 15+ px long and at least 0.3 of the forearm, the
    hand model 0.6+ sure, its wrist point near YOLO's wrist,
  - the bend is one a wrist makes (90 deg at most),
  - 2+ frames within +-0.06 s of the sample agree (25 deg at most apart; the
    median is used),
  - the bend is `min`+ degrees.
Studio's _G.wristMisses (head_misses.lua) reads these lines.
"""
import sys, math, statistics as st
from pathlib import Path
import numpy as np, cv2
from ultralytics import YOLO
import mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision

pose = YOLO(sys.argv[1])
hands = vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
    base_options=mpt.BaseOptions(model_asset_path=sys.argv[2]), running_mode=vision.RunningMode.IMAGE,
    num_hands=2, min_hand_detection_confidence=0.5, min_hand_presence_confidence=0.5))
clipdir = Path(sys.argv[3]); names = sys.argv[4].split(",")
step = float(sys.argv[5]) if len(sys.argv) > 5 else 0.2
MIN = float(sys.argv[6]) if len(sys.argv) > 6 else 25

def ang(v):
    return math.degrees(math.atan2(v[1], v[0]))

for name in names:
    cap = cv2.VideoCapture(str(clipdir / name)); fps = cap.get(5) or 30
    w, h = cap.get(3), cap.get(4)
    got = {}; prev = None; f = 0
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
        for side, (ei, wi) in enumerate([(7, 9), (8, 10)]):
            el, wr = kp[ei], kp[wi]
            if min(el[2], wr[2]) < 0.5: continue
            fa = np.array([wr[0] - el[0], wr[1] - el[1]]); L = float(np.linalg.norm(fa))
            if L < 25: continue
            s = L * 0.65
            x0, y0 = int(max(wr[0] - s, 0)), int(max(wr[1] - s, 0))
            x1, y1 = int(min(wr[0] + s, w)), int(min(wr[1] + s, h))
            if x1 - x0 < 16 or y1 - y0 < 16: continue
            crop = cv2.cvtColor(img[y0:y1, x0:x1], cv2.COLOR_BGR2RGB)
            sc = 320 / max(crop.shape[:2]); crop = cv2.resize(crop, None, fx=sc, fy=sc)
            det = hands.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(crop)))
            pick = None
            for j, lm in enumerate(det.hand_landmarks):
                score = det.handedness[j][0].score if j < len(det.handedness) else 0
                if score < 0.6: continue
                px = np.array([[q.x * crop.shape[1] / sc + x0, q.y * crop.shape[0] / sc + y0] for q in lm])
                d = math.hypot(px[0][0] - wr[0], px[0][1] - wr[1])
                if d < L * 0.35 and (pick is None or d < pick[0]): pick = (d, px)
            if not pick: continue
            hand = pick[1][9] - pick[1][0]; hl = float(np.linalg.norm(hand))
            if hl < 15 or hl < 0.3 * L: continue
            bend = (ang(hand) - ang(fa) + 180) % 360 - 180
            if abs(bend) > 90: continue
            got.setdefault((side, k), []).append(bend)
    parts = {0: [], 1: []}
    for (side, k), vals in sorted(got.items(), key=lambda x: (x[0][0], x[0][1])):
        if len(vals) < 2 or max(vals) - min(vals) > 25: continue
        v = st.median(vals)
        if abs(v) >= MIN: parts[side].append("%g=%d" % (round(k * step, 2), round(v)))
    print(name, "L:" + ",".join(parts[0]), "R:" + ",".join(parts[1]), flush=True)
