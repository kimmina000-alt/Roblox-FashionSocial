"""(D-1192) Wrist and hand moves of the centre dancer, read from the video, so the choreo session finds
them itself (user 2026-11-10: "안무 하나하나 잡아서 말해야 하는 거 힘들다. 니가 세세한 부분까지 캐치할 방법 찾아봐").

python -I hand_moves.py <video> --off <song - video seconds> [--from s] [--to s] [--x 0.5] [--step 0.1]
       [--model <pose_landmarker_full.task>] [--json out.json]

Every --step seconds (song time) MediaPipe Pose (33 points, with index / pinky / thumb) is read for the
dancer nearest --x (0..1 of the frame width, default the centre). Per hand:
  up    wrist height over the shoulder, in torso lengths (+ = above)
  ext   elbow angle (180 = straight arm)
  flex  hand vs forearm on screen, degrees (+ / - = the two ways it bends; compare its sign with a known 꺾기)
  palm  +1 / -1 = which side of the hand faces the camera (flips on a twist)
Events (merged runs, song seconds):
  반짝   palm side flips 2+ times inside 1 s (twinkle / 반짝반짝)
  돌리기 the hand turns 300°+ around the wrist inside 1.2 s (wrist circles)
  흔들기 flex swings 2+ times by 25°+ (wave / flick)
  꺾기   |flex| over 35° for 0.3 s+ (sign kept)
  뻗기   elbow over 150° with the hand away from the body (arm out)
Sides are MediaPipe's landmark sides. On the mirrored videos the choreographies were made from they already
match the game's hand names (Genie: the right arm out at 1:08 reads R): leave --mirror off there; --mirror swaps.
Only the hand model's readings make events (the pose model's finger points are too rough); circles and twinkles
both show as palm flips ("twinkle"), so read the type from the user's words or the raw `hdir`.
Checked on Genie 1:06-1:16 (--step 0.05): R 67.7-69.05, both 69.4-71.4 = the game's arms out (1:08 R, 1:09-10 both)."""
import argparse, json, math, os, sys

import cv2
import mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision

DEF_MODEL = os.path.join(os.environ.get("TEMP", ""), "claude", "8459f2474e5f6ee9",
                         "9d3f70b0-88cf-41aa-859c-c20bebe76d4b", "scratchpad", "models", "pose_landmarker_full.task")
SH, EL, WR, PI, IN, TH, HIP = {"L": 11, "R": 12}, {"L": 13, "R": 14}, {"L": 15, "R": 16}, {"L": 17, "R": 18}, \
    {"L": 19, "R": 20}, {"L": 21, "R": 22}, {"L": 23, "R": 24}


def angle2(v):
    return math.degrees(math.atan2(v[1], v[0]))


def wrap(a):
    return (a + 180) % 360 - 180


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--off", type=float, default=0.0, help="song seconds = video seconds + off")
    ap.add_argument("--from", dest="t0", type=float, default=None)
    ap.add_argument("--to", dest="t1", type=float, default=None)
    ap.add_argument("--x", type=float, default=0.5)
    ap.add_argument("--step", type=float, default=0.1)
    ap.add_argument("--model", default=DEF_MODEL)
    ap.add_argument("--mirror", action="store_true")
    ap.add_argument("--json")
    ap.add_argument("--raw", action="store_true", help="print every sample too")
    a = ap.parse_args()

    cap = cv2.VideoCapture(a.video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    dur = cap.get(cv2.CAP_PROP_FRAME_COUNT) / fps
    t0 = a.t0 if a.t0 is not None else a.off
    t1 = a.t1 if a.t1 is not None else dur + a.off
    opts = vision.PoseLandmarkerOptions(base_options=mpt.BaseOptions(model_asset_path=a.model),
                                        running_mode=vision.RunningMode.VIDEO, num_poses=6,
                                        min_pose_detection_confidence=0.4, min_tracking_confidence=0.4)
    det = vision.PoseLandmarker.create_from_options(opts)
    hm = os.path.join(os.path.dirname(a.model), "hand_landmarker.task")
    hands = vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
        base_options=mpt.BaseOptions(model_asset_path=hm), num_hands=2, min_hand_detection_confidence=0.3)) \
        if os.path.exists(hm) else None
    samples, cx, s = [], a.x, t0
    while s <= t1 + 1e-6:
        vt = s - a.off
        if vt < 0 or vt > dur:
            s += a.step
            continue
        cap.set(cv2.CAP_PROP_POS_MSEC, vt * 1000)
        ok, fr = cap.read()
        if not ok:
            break
        h, w = fr.shape[:2]
        img = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(fr, cv2.COLOR_BGR2RGB))
        res = det.detect_for_video(img, int(vt * 1000))
        best = None
        for lm in res.pose_landmarks or []:
            x = (lm[11].x + lm[12].x + lm[23].x + lm[24].x) / 4
            if best is None or abs(x - cx) < abs(best[0] - cx):
                best = (x, lm)
        row = {"t": round(s, 2)}
        if best:
            cx = cx * 0.7 + best[0] * 0.3  # follow the same dancer
            lm = best[1]
            P = lambda i: (lm[i].x * w, lm[i].y * h)
            torso = math.dist(((P(11)[0] + P(12)[0]) / 2, (P(11)[1] + P(12)[1]) / 2),
                              ((P(23)[0] + P(24)[0]) / 2, (P(23)[1] + P(24)[1]) / 2)) or 1
            for k in ("L", "R"):
                side = ("R" if k == "L" else "L") if a.mirror else k
                sh, el, wr, pi, ix = P(SH[k]), P(EL[k]), P(WR[k]), P(PI[k]), P(IN[k])
                vis = min(lm[WR[k]].visibility, lm[EL[k]].visibility)
                if vis < 0.4:
                    continue
                fa = (wr[0] - el[0], wr[1] - el[1])
                ua = (el[0] - sh[0], el[1] - sh[1])
                hd = ((pi[0] + ix[0]) / 2 - wr[0], (pi[1] + ix[1]) / 2 - wr[1])
                cr = (ix[0] - wr[0]) * (pi[1] - wr[1]) - (ix[1] - wr[1]) * (pi[0] - wr[0])
                nz, src = (1 if cr > 0 else -1), "pose"
                # the hand model on a crop round the hand: 21 points, a real palm normal
                if hands:
                    hc = (wr[0] + hd[0] * 0.6, wr[1] + hd[1] * 0.6)
                    half = max(40, torso * 0.45)
                    x0, y0 = int(max(0, hc[0] - half)), int(max(0, hc[1] - half))
                    x1, y1 = int(min(w, hc[0] + half)), int(min(h, hc[1] + half))
                    if x1 - x0 > 20 and y1 - y0 > 20:
                        crop = cv2.cvtColor(fr[y0:y1, x0:x1], cv2.COLOR_BGR2RGB)
                        crop = cv2.resize(crop, (256, 256))
                        hr = hands.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=crop))
                        pick = None
                        for hl in hr.hand_landmarks or []:
                            d = abs(hl[0].x * (x1 - x0) + x0 - wr[0]) + abs(hl[0].y * (y1 - y0) + y0 - wr[1])
                            if d < half * 0.9 and (pick is None or d < pick[0]):
                                pick = (d, hl)
                        if pick:
                            hl = pick[1]
                            Q = lambda i: (hl[i].x * (x1 - x0) + x0, hl[i].y * (y1 - y0) + y0, hl[i].z * (x1 - x0))
                            w0, i5, m9, p17 = Q(0), Q(5), Q(9), Q(17)
                            u = (i5[0] - w0[0], i5[1] - w0[1], i5[2] - w0[2])
                            v = (p17[0] - w0[0], p17[1] - w0[1], p17[2] - w0[2])
                            nrm = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
                            ln = math.sqrt(sum(c * c for c in nrm)) or 1
                            nz = nrm[2] / ln  # -1..1: palm toward / away from the camera
                            hd = (m9[0] - w0[0], m9[1] - w0[1])
                            src = "hand"
                ext = 180 - abs(wrap(angle2(fa) - angle2(ua)))
                flex = wrap(angle2(hd) - angle2(fa))
                row[side] = {"up": round((sh[1] - wr[1]) / torso, 2), "ext": round(ext), "flex": round(flex),
                             "palm": 1 if nz > 0 else -1, "nz": round(nz, 2), "hdir": round(angle2(hd)),
                             "out": round(math.dist(wr, sh) / torso, 2), "src": src}
        samples.append(row)
        s += a.step
    det.close()

    events = []
    for side in ("L", "R"):
        seq = [(r["t"], r.get(side)) for r in samples]
        n = len(seq)
        def run(flag, name):
            i = 0
            while i < n:
                if flag[i]:
                    j = i
                    while j + 1 < n and flag[j + 1]:
                        j += 1
                    events.append({"hand": side, "type": name, "from": seq[i][0], "to": round(seq[j][0] + a.step, 2)})
                    i = j + 1
                else:
                    i += 1
        win = max(1, round(1.0 / a.step))
        tw, ci, wa, be, ar = [False] * n, [False] * n, [False] * n, [False] * n, [False] * n
        for i in range(n):
            # only the hand model's readings count (the pose model's finger points are too rough)
            part = [v for _, v in seq[i:i + win] if v and v.get("src") == "hand"]
            if len(part) >= win * 0.6:
                sure = [p for p in part if abs(p.get("nz", 0)) > 0.5]
                flips = sum(1 for p, q in zip(sure, sure[1:]) if p["palm"] != q["palm"])
                if flips >= 3:
                    for j in range(i, min(n, i + win)):
                        tw[j] = True
                rot = 0
                for p, q in zip(part, part[1:]):
                    rot += wrap(q["hdir"] - p["hdir"])
                d = [p["flex"] for p in part]
                d = [sorted(d[max(0, k - 1):k + 2])[len(d[max(0, k - 1):k + 2]) // 2] for k in range(len(d))]  # median of 3
                sw, last, ext = 0, None, d[0]
                for q in d[1:]:
                    if last is None:
                        if abs(q - ext) > 25:
                            last = 1 if q > ext else -1
                            ext = q
                    elif (q - ext) * last > 0:
                        ext = q
                    elif abs(q - ext) > 25:
                        sw += 1
                        last = -last
                        ext = q
                if abs(rot) >= 300:
                    for j in range(i, min(n, i + round(1.2 / a.step))):
                        ci[j] = True
                if sw >= 3:
                    for j in range(i, min(n, i + win)):
                        wa[j] = True
            v = seq[i][1]
            if v:
                be[i] = v.get("src") == "hand" and abs(v["flex"]) > 35
                ar[i] = v["ext"] > 150 and v["out"] > 0.9
        # 꺾기 needs 0.3 s
        k3 = max(1, round(0.3 / a.step))
        be = [all(be[j] for j in range(i, min(n, i + k3))) or (i >= k3 - 1 and all(be[j] for j in range(i - k3 + 1, i + 1))) for i in range(n)]
        run(tw, "twinkle")
        run(ci, "circle")
        run(wa, "wave")
        run(be, "bend")
        run(ar, "out")
    for e in events:
        fl = [r[e["hand"]]["flex"] for r in samples if e["from"] <= r["t"] < e["to"] and r.get(e["hand"])]
        if fl and e["type"] == "bend":
            e["flex"] = round(sum(fl) / len(fl))
    events.sort(key=lambda e: (e["from"], e["hand"]))
    for e in events:
        if e["to"] - e["from"] >= 0.2:
            print(f'{e["from"]:7.2f}-{e["to"]:7.2f} {e["hand"]} {e["type"]}' + (f' {e["flex"]:+d}°' if "flex" in e else ""))
    if a.raw:
        for r in samples:
            print(r["t"], json.dumps({k: v for k, v in r.items() if k != "t"}, ensure_ascii=False))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"samples": samples, "events": events}, f, ensure_ascii=False)


if __name__ == "__main__":
    main()
