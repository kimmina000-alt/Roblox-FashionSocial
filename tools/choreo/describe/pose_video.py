"""The original dance video -> pose json (pose_common.py format), every --step seconds of song time (D-1863).

python -I pose_video.py <video> --off <song - video seconds> --out video.json
       [--cc <centercut folder>]   follow the dancer the centercut clips follow (clips.json ids, tracks.json boxes)
       [--x 0.5]                   without --cc: the dancer nearest this spot (0..1 of the width)
       [--from s] [--to s]         song seconds
       [--step 0.05] [--no-hands]

MediaPipe Pose (33 points, 3D "world" points) runs on a crop round the dancer, the hand model on a crop round
each wrist (palm normal and hand direction for wrist bends). Heights over the floor and travel come from the
picture: floor = the lowest foot in +-1.5 s, so they are right only while the camera stands still.
Sides are the dancer's own (MediaPipe's), as on a capture made from this same video."""
import argparse, json, math, os, sys

import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision

HERE = os.path.dirname(os.path.abspath(__file__))
CC_DIRS = [os.path.join(HERE, "..", "centercut"), r"D:\Roblox\Roblox-FashionSocial\tools\choreo\centercut"]
for d in CC_DIRS:
    if os.path.exists(os.path.join(d, "centercut.py")):
        sys.path.insert(0, d)
        break
MODEL_DIRS = [os.path.join(d, "models") for d in CC_DIRS]

MPI = {"nose": 0, "lear": 7, "rear": 8, "lsho": 11, "rsho": 12, "lelb": 13, "relb": 14, "lwri": 15, "rwri": 16,
       "lhip": 23, "rhip": 24, "lkne": 25, "rkne": 26, "lank": 27, "rank": 28, "ltoe": 31, "rtoe": 32,
       "lheel": 29, "rheel": 30}
HEEL = {"l": 29, "r": 30}
PINKY, INDEX = {"l": 17, "r": 18}, {"l": 19, "r": 20}


def model(name):
    for d in MODEL_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    raise SystemExit("model not found: " + name + " (put it in tools/choreo/centercut/models)")


def W(lm):
    """MediaPipe world point -> x right, y up, z toward the camera."""
    return [lm.x, -lm.y, -lm.z]


def hand_vectors(side, pts):
    """Hand direction and palm normal from wrist / index knuckle / pinky knuckle / middle knuckle (camera frame)."""
    w, i, p, m = pts
    hd = [m[0] - w[0], m[1] - w[1], m[2] - w[2]]
    u = [i[0] - w[0], i[1] - w[1], i[2] - w[2]]
    v = [p[0] - w[0], p[1] - w[1], p[2] - w[2]]
    c = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
    if side == "l":
        c = [-c[0], -c[1], -c[2]]
    n = math.sqrt(sum(x * x for x in c)) or 1
    return hd, [x / n for x in c]


def followed(folder, video):
    """The dancer the centercut clips follow, frame by frame (centercut.choose: clothes colours + seeds),
    cached in <folder>/followed.json."""
    cache = os.path.join(folder, "followed.json")
    T = json.load(open(os.path.join(folder, "tracks.json"), encoding="utf-8"))
    if os.path.exists(cache) and os.path.getmtime(cache) > os.path.getmtime(os.path.join(folder, "cuts.json")):
        return json.load(open(cache, encoding="utf-8")), T["meta"]["fps"]
    import centercut as cc
    doc = json.load(open(os.path.join(folder, "cuts.json"), encoding="utf-8"))
    if doc.get("members"):
        T["members"] = doc["members"]
    T["video"] = video
    print("following the centercut dancer (once per folder)...", file=sys.stderr)
    chosen, _, _ = cc.choose(T, doc["cuts"], argparse.Namespace(conf=0.35, exclude_dark=0.6, dark_gap=0.35))  # (centercut.py defaults)
    out = [{"box": [round(v, 1) for v in p["box"]]} if p else None for p in chosen]
    json.dump(out, open(cache, "w", encoding="utf-8"))
    return out, T["meta"]["fps"]


def floor_and_travel(samples, step, frame_h):
    """Heights over the floor ("h") and travel ("tr") from the picture, in torso lengths.
    Pixels per world unit come from the torso (its 3D length undoes bending toward the camera). A camera cut
    or zoom (that scale jumping 15 %+) starts a new stretch: the floor (the lowest foot within +-1.5 s) and
    the travel are measured inside one stretch only. Feet out of the picture give no heights."""
    n = len(samples)
    raw = []
    for r in samples:
        P, im = r.get("p"), r.get("img")
        if not P or not im:
            raw.append(None)
            continue
        sw = [(P["lsho"][j] + P["rsho"][j]) / 2 - (P["lhip"][j] + P["rhip"][j]) / 2 for j in range(3)]
        spx = [(im["lsho"][j] + im["rsho"][j]) / 2 - (im["lhip"][j] + im["rhip"][j]) / 2 for j in range(2)]
        tw, flat = math.sqrt(sum(v * v for v in sw)), math.hypot(sw[0], sw[1])
        raw.append((math.hypot(*spx) / flat, tw) if tw > 0 and flat > 0.4 * tw else (None, tw))
    med = []
    for i in range(n):
        seg = sorted(x[0] for x in raw[max(0, i - 2):i + 3] if x and x[0])
        med.append(seg[len(seg) // 2] if seg else None)
    # stretches between camera cuts / zooms
    seg_id, cur, last = [], 0, None
    for i in range(n):
        if med[i] and last and max(med[i] / last, last / med[i]) > 1.15:
            cur += 1
        if med[i]:
            last = med[i]
        seg_id.append(cur)
    win = int(round(1.5 / step))
    sm = []
    for i in range(n):
        seg = sorted(med[j] for j in range(max(0, i - win // 3), min(n, i + win // 3 + 1)) if med[j] and seg_id[j] == seg_id[i])
        sm.append(seg[len(seg) // 2] if seg else None)
    feet = []
    for r in samples:
        im = r.get("img")
        if not im:
            feet.append(None)
            continue
        y = max(im[k][1] for k in ("lank", "rank", "ltoe", "rtoe", "lheel", "rheel"))
        feet.append(None if (frame_h and y > frame_h - 4) else y)
    trx = trz = 0.0
    lastp = None
    for i, r in enumerate(samples):
        r.pop("h", None)
        if "p" not in r or not sm[i] or not raw[i]:
            lastp = None
            continue
        unit_px = raw[i][1] * sm[i]
        im = r["img"]
        seg = sorted(feet[j] for j in range(max(0, i - win), min(n, i + win + 1)) if feet[j] is not None and seg_id[j] == seg_id[i])
        if feet[i] is not None and len(seg) >= win // 2:
            ground = seg[int(len(seg) * 0.9)]
            h = {}
            for k in ("lwri", "rwri", "lkne", "rkne"):
                h[k] = round((ground - im[k][1]) / unit_px, 3)
            for l in ("l", "r"):
                h[l + "ank"] = round((ground - max(im[l + "ank"][1], im[l + "heel"][1], im[l + "toe"][1])) / unit_px, 3)
                h[l + "toe"] = round((ground - im[l + "toe"][1]) / unit_px, 3)
                h[l + "heel"] = round((ground - im[l + "heel"][1]) / unit_px, 3)
            h["hip"] = round((ground - (im["lhip"][1] + im["rhip"][1]) / 2) / unit_px, 3)
            r["h"] = h
        hx = (im["lhip"][0] + im["rhip"][0]) / 2
        if lastp is not None and lastp[2] == seg_id[i]:
            dx = (hx - lastp[0]) / unit_px
            dz = math.log(sm[i] / lastp[1]) * 10  # rough: about 10 torso lengths from the camera
            if abs(dx) < 1.0 and abs(dz) < 1.0:
                trx += dx
                trz += dz
        lastp = (hx, sm[i], seg_id[i])
        r["tr"] = [round(trx, 3), round(trz, 3)]
        r["cam"] = seg_id[i]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--off", type=float, default=0.0, help="song seconds = video seconds + off")
    ap.add_argument("--cc")
    ap.add_argument("--x", type=float, default=0.5)
    ap.add_argument("--from", dest="t0", type=float)
    ap.add_argument("--to", dest="t1", type=float)
    ap.add_argument("--step", type=float, default=0.05)
    ap.add_argument("--no-hands", action="store_true")
    ap.add_argument("--out", required=True)
    ap.add_argument("--refloor", action="store_true", help="only redo floor and travel of an existing --out file")
    a = ap.parse_args()
    if a.refloor:
        d = json.load(open(a.out, encoding="utf-8"))
        cap = cv2.VideoCapture(d["video"])
        floor_and_travel(d["samples"], d["step"], cap.get(4))
        json.dump(d, open(a.out, "w", encoding="utf-8"), ensure_ascii=False)
        print("refloored", a.out)
        return

    cap = cv2.VideoCapture(a.video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    nfr = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    dur = nfr / fps
    FW, FH = cap.get(3), cap.get(4)
    t0 = a.t0 if a.t0 is not None else max(0.0, a.off)
    t1 = a.t1 if a.t1 is not None else dur + a.off

    crop_pose = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
        base_options=mpt.BaseOptions(model_asset_path=model("pose_landmarker_full.task")),
        running_mode=vision.RunningMode.IMAGE, num_poses=3, min_pose_detection_confidence=0.3))
    full_pose = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
        base_options=mpt.BaseOptions(model_asset_path=model("pose_landmarker_full.task")),
        running_mode=vision.RunningMode.IMAGE, num_poses=6, min_pose_detection_confidence=0.3))
    hands = None
    if not a.no_hands:
        hands = vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
            base_options=mpt.BaseOptions(model_asset_path=model("hand_landmarker.task")), num_hands=2,
            min_hand_detection_confidence=0.2, min_hand_presence_confidence=0.2))

    track = None
    if a.cc:
        track, fps_t = followed(a.cc, a.video)

    samples, cx, prev = [], a.x, None
    frame_i, img = -1, None
    s = t0
    while s <= t1 + 1e-6:
        vt = s - a.off
        if vt < 0:
            s += a.step
            continue
        want = int(round(vt * fps))
        if want >= nfr:
            break
        while frame_i < want:
            ok = cap.grab()
            frame_i += 1
            if not ok:
                break
        ok, img = cap.retrieve()
        if not ok:
            break
        lm = wl = None
        x0 = y0 = 0
        cw, ch = FW, FH
        if track:
            boxes = track
            f = int(round(vt * fps_t))
            p = boxes[f] if 0 <= f < len(boxes) else None
            b = p["box"] if p else None
            if b:
                bx, by, bw, bh = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2, b[2] - b[0], b[3] - b[1]
                side = max(bw, bh) * 1.35
                x0, y0 = int(bx - side / 2), int(by - side / 2)
                cw = ch = int(side)
                pad = cv2.copyMakeBorder(img, max(0, -y0), max(0, y0 + ch - int(FH)), max(0, -x0), max(0, x0 + cw - int(FW)),
                                         cv2.BORDER_CONSTANT)
                px0, py0 = x0 + max(0, -x0), y0 + max(0, -y0)
                crop = pad[py0:py0 + ch, px0:px0 + cw].copy()
                # grey out everything outside the followed box (the members next to the dancer)
                mx, my = 0.08 * bh, 0.05 * bh
                ax0, ay0 = int(b[0] - mx - x0), int(b[1] - my - y0)
                ax1, ay1 = int(b[2] + mx - x0), int(b[3] + my - y0)
                mask = np.full(crop.shape[:2], True)
                mask[max(0, ay0):max(0, ay1), max(0, ax0):max(0, ax1)] = False
                crop[mask] = 110
                r = crop_pose.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)))
                best = None
                for k, L in enumerate(r.pose_landmarks or []):
                    tx = x0 + (L[11].x + L[12].x + L[23].x + L[24].x) / 4 * cw
                    ty = y0 + (L[11].y + L[12].y + L[23].y + L[24].y) / 4 * ch
                    d = abs(tx - bx) / bw + (math.hypot(tx - prev[0], ty - prev[1]) / bh if prev else 0)
                    if best is None or d < best[0]:
                        best = (d, k, (tx, ty))
                if best:
                    lm, wl = r.pose_landmarks[best[1]], r.pose_world_landmarks[best[1]]
                    prev = best[2]
            else:
                prev = None
        else:
            r = full_pose.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(img, cv2.COLOR_BGR2RGB)))
            best = None
            for k, L in enumerate(r.pose_landmarks or []):
                x = (L[11].x + L[12].x + L[23].x + L[24].x) / 4
                if best is None or abs(x - cx) < abs(best[0] - cx):
                    best = (x, k)
            if best:
                cx = cx * 0.7 + best[0] * 0.3
                lm, wl = r.pose_landmarks[best[1]], r.pose_world_landmarks[best[1]]
        row = {"t": round(s, 3), "vt": round(vt, 3)}
        if lm is not None and min(lm[11].visibility, lm[12].visibility, lm[23].visibility, lm[24].visibility) > 0.3:
            P = {n: W(wl[i]) for n, i in MPI.items() if lm[i].visibility > 0.25 or n in ("lhip", "rhip", "lsho", "rsho")}
            px = lambda i: [x0 + lm[i].x * cw, y0 + lm[i].y * ch]
            row["img"] = {n: [round(v, 1) for v in px(i)] for n, i in MPI.items()}
            for l in ("l", "r"):
                row["img"][l + "heel"] = [round(v, 1) for v in px(HEEL[l])]
            row["vis"] = {n: round(lm[i].visibility, 2) for n, i in MPI.items()}
            hd, pn, hs = {}, {}, {}
            for l, k in (("l", "L"), ("r", "R")):
                wi, ii, pi = MPI[l + "wri"], INDEX[l], PINKY[l]
                if lm[wi].visibility < 0.3:
                    continue
                got, src = None, "pose"
                if hands:
                    wx, wy = px(wi)
                    ex, ey = px(MPI[l + "elb"])
                    fl = math.hypot(wx - ex, wy - ey)
                    hx, hy = wx + (wx - ex) * 0.35, wy + (wy - ey) * 0.35
                    for fac in (2.2, 1.1):  # (wide finds more hands; tight finds some the wide one misses)
                        size = max(48, fac * fl)
                        a0, b0 = int(max(0, hx - size)), int(max(0, hy - size))
                        a1, b1 = int(min(FW, hx + size)), int(min(FH, hy + size))
                        if a1 - a0 <= 16 or b1 - b0 <= 16:
                            continue
                        hc = cv2.resize(cv2.cvtColor(img[b0:b1, a0:a1], cv2.COLOR_BGR2RGB), (256, 256))
                        hr = hands.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=hc))
                        pick = None
                        for hl, hw in zip(hr.hand_landmarks or [], hr.hand_world_landmarks or []):
                            dpx = math.hypot(hl[0].x * (a1 - a0) + a0 - wx, hl[0].y * (b1 - b0) + b0 - wy)
                            if dpx < max(size * 0.3, fl * 0.5) and (pick is None or dpx < pick[0]):
                                pick = (dpx, hw, hl)
                        if pick:
                            hw = pick[1]
                            got = hand_vectors(l, [W(hw[0]), W(hw[5]), W(hw[17]), W(hw[9])])
                            src = "hand"
                            P[l + "hand"] = [P[l + "wri"][j] + got[0][j] for j in range(3)]
                            hl = pick[2]
                            row["img"][l + "knu"] = [round(hl[9].x * (a1 - a0) + a0, 1), round(hl[9].y * (b1 - b0) + b0, 1)]
                            break
                if got is None and lm[ii].visibility > 0.3 and lm[pi].visibility > 0.3:
                    wv, iv, pv = W(wl[wi]), W(wl[ii]), W(wl[pi])
                    mv = [(iv[j] + pv[j]) / 2 for j in range(3)]
                    got = hand_vectors(l, [wv, iv, pv, mv])
                    P[l + "hand"] = mv
                if got:
                    hd[k], pn[k] = [round(v, 4) for v in got[0]], [round(v, 4) for v in got[1]]
                    hs[k] = src
            row["p"] = {n: [round(v, 4) for v in xyz] for n, xyz in P.items()}
            row["hd"], row["pn"], row["hs"] = hd, pn, hs
        samples.append(row)
        if len(samples) % 200 == 0:
            print("  %s s" % round(s, 1), file=sys.stderr)
        s = round(s + a.step, 6)

    floor_and_travel(samples, a.step, FH)
    json.dump({"source": "video", "video": os.path.abspath(a.video), "off": a.off, "step": a.step, "samples": samples},
              open(a.out, "w", encoding="utf-8"), ensure_ascii=False)
    print("wrote %s (%d samples, %d with a body)" % (a.out, len(samples), sum(1 for r in samples if "p" in r)))


if __name__ == "__main__":
    main()
