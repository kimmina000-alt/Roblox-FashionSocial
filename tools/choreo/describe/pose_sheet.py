"""Picture sheet: the original video round the dancer (with the points it read) beside the game's pose drawn as a
stick figure from the front, at the same song times (D-1863). For looking at what the text says by eye.

python pose_sheet.py <video.json> [<game.json>] --from s --to s [--step 0.1] [--cols 8] --out sheet.jpg
"""
import argparse, json, math, os, sys

import cv2

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pose_common as pc
import numpy as np

BONES = [("lsho", "rsho"), ("lsho", "lelb"), ("lelb", "lwri"), ("rsho", "relb"), ("relb", "rwri"), ("lsho", "lhip"),
         ("rsho", "rhip"), ("lhip", "rhip"), ("lhip", "lkne"), ("lkne", "lank"), ("rhip", "rkne"), ("rkne", "rank"),
         ("lank", "ltoe"), ("rank", "rtoe"), ("lwri", "lhand"), ("rwri", "rhand"), ("lwri", "lknu"), ("rwri", "rknu")]
LEFT = (255, 140, 40)   # BGR: the dancer's left = blue
RIGHT = (60, 60, 240)   # right = red
TILE = 220


def near(samples, t):
    best = None
    for r in samples:
        if best is None or abs(r["t"] - t) < abs(best["t"] - t):
            best = r
    return best if best and abs(best["t"] - t) < 0.06 else None


def colour(a, b):
    return LEFT if a.startswith("l") and b.startswith("l") else (RIGHT if a.startswith("r") and b.startswith("r") else (200, 200, 200))


class Reader:
    """Frames in time order: one seek, then reading forward (seeking every frame is slow on H.264)."""
    def __init__(self, path):
        self.cap = cv2.VideoCapture(path)
        self.fps = self.cap.get(cv2.CAP_PROP_FPS) or 30
        self.i, self.img = None, None

    def frame(self, t):
        want = int(round(t * self.fps))
        if self.i is None or want < self.i or want - self.i > 90:
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, want)
            self.i = want - 1
        while self.i < want:
            ok = self.cap.grab()
            self.i += 1
            if not ok:
                return False, None
        ok, img = self.cap.retrieve()
        return ok, img


def video_tile(cap, r):
    tile = np.zeros((TILE, TILE, 3), np.uint8)
    if not r:
        return tile
    ok, img = cap.frame(r["vt"])
    if not ok or "img" not in r:
        return tile
    im = r["img"]
    for a, b in BONES:
        if a in im and b in im:
            cv2.line(img, tuple(int(v) for v in im[a]), tuple(int(v) for v in im[b]), colour(a, b), 3)
    xs = [v[0] for v in im.values()]
    ys = [v[1] for v in im.values()]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    side = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.25 + 20
    x0, y0 = int(cx - side / 2), int(cy - side / 2)
    H, W = img.shape[:2]
    pad = cv2.copyMakeBorder(img, max(0, -y0), max(0, y0 + int(side) - H), max(0, -x0), max(0, x0 + int(side) - W), cv2.BORDER_CONSTANT)
    crop = pad[y0 + max(0, -y0):y0 + max(0, -y0) + int(side), x0 + max(0, -x0):x0 + max(0, -x0) + int(side)]
    return cv2.resize(crop, (TILE, TILE)) if crop.size else tile


def game_tile(r):
    tile = np.full((TILE, TILE, 3), 30, np.uint8)
    if not r or "p" not in r:
        return tile
    P = r["p"]
    sh = [(P["lsho"][i] + P["rsho"][i]) / 2 for i in range(3)]
    hp = [(P["lhip"][i] + P["rhip"][i]) / 2 for i in range(3)]
    torso = math.dist(sh, hp) or 1
    k = TILE / (5.2 * torso)
    base = TILE * 0.55
    pt = lambda v: (int(TILE / 2 + v[0] * k), int(base - v[1] * k))
    # floor line from the feet heights
    h = r.get("h") or {}
    if "lank" in P and "lank" in h:
        fy = P["lank"][1] - h["lank"] * torso
        cv2.line(tile, (0, int(base - fy * k)), (TILE, int(base - fy * k)), (90, 90, 90), 1)
    # depth shown by size: nearer = thicker
    for a, b in BONES:
        if a in P and b in P:
            z = (P[a][2] + P[b][2]) / 2 / torso
            cv2.line(tile, pt(P[a]), pt(P[b]), colour(a, b), max(1, int(3 + z * 2)))
    if "nose" in P:
        cv2.circle(tile, pt(P["nose"]), 5, (255, 255, 255), -1)
    f = pc.features(r)
    if f:  # (bending toward the camera does not show from the front: numbers in the corner)
        txt = "tilt %d yaw %+d" % (round(f["tilt"]), round(f["yaw"]))
        cv2.putText(tile, txt, (4, TILE - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (200, 200, 200), 1)
    for side, key in (("l", "L"), ("r", "R")):
        hd = (r.get("hd") or {}).get(key)
        w = P.get(side + "wri")
        if hd and w:
            n = math.sqrt(sum(x * x for x in hd)) or 1
            e = [w[i] + hd[i] / n * 0.25 * torso for i in range(3)]
            cv2.line(tile, pt(w), pt(e), (80, 255, 80), 2)
    return tile


def label(tile, text):
    cv2.putText(tile, text, (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 0), 3)
    cv2.putText(tile, text, (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--from", dest="t0", type=float, required=True)
    ap.add_argument("--to", dest="t1", type=float, required=True)
    ap.add_argument("--step", type=float, default=0.1)
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--mirror", action="store_true", help="draw the video's 3D points mirrored (as compared)")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    V = json.load(open(a.files[0], encoding="utf-8"))
    G = json.load(open(a.files[1], encoding="utf-8")) if len(a.files) > 1 else None
    cap = Reader(V["video"]) if V.get("video") else None
    times, t = [], a.t0
    while t <= a.t1 + 1e-6:
        times.append(round(t, 3))
        t += a.step
    cells = []
    for t in times:
        rv = near(V["samples"], t)
        col = []
        if V["source"] == "video":
            vt = video_tile(cap, rv)
            label(vt, "%d:%04.1f" % (t // 60, t % 60))
            col.append(vt)
        else:
            gt = game_tile(rv)
            label(gt, "%d:%04.1f" % (t // 60, t % 60))
            col.append(gt)
        if G:
            col.append(game_tile(near(G["samples"], t)))
        if V["source"] == "video":
            col.append(game_tile(pc.mirror_samples([rv])[0] if (a.mirror and rv and "p" in rv) else rv))  # what the video's 3D points look like drawn the game's way
        cells.append(np.vstack(col))
    rows = []
    for i in range(0, len(cells), a.cols):
        row = cells[i:i + a.cols]
        while len(row) < a.cols:
            row.append(np.zeros_like(cells[0]))
        rows.append(np.hstack(row))
    sheet = np.vstack([np.vstack([r, np.full((6, r.shape[1], 3), 255, np.uint8)]) for r in rows])
    cv2.imwrite(a.out, sheet, [cv2.IMWRITE_JPEG_QUALITY, 85])
    print("wrote", a.out, sheet.shape[1], "x", sheet.shape[0])


if __name__ == "__main__":
    main()
