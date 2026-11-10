"""Where the centre dancer of each centercut clip is hidden by someone in front, or lost.
python -I occlusion_scan.py <centercut folder> [<more folders>]  -> one line per clip with the hidden stretches
(clip seconds). Also the dancer's own motion per 0.5 s (body-normalised keypoint speed) to compare with the capture."""
import json, sys, os, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "centercut"))  # centercut.stitch_ids / hist_of
sys.path.insert(1, r"D:\Roblox\Roblox-FashionSocial\tools\choreo\centercut")  # (centercut.py is not committed: the main folder's copy)
import centercut as cc

BODY = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]


def inter(a, b):
    x0, y0, x1, y1 = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
    return max(0, x1 - x0) * max(0, y1 - y0)


def scan(folder):
    T = json.load(open(os.path.join(folder, "tracks.json"), encoding="utf-8"))
    C = json.load(open(os.path.join(folder, "clips.json"), encoding="utf-8"))
    fps, F = T["meta"]["fps"], T["frames"]
    root = cc.stitch_ids(F, fps)
    out = []
    for name in sorted(C, key=lambda n: int(n.split(".")[0])):
        c = C[name]
        if len(c.get("ids", [])) != 1:
            out.append((name, "several ids, skipped", [], []))
            continue
        who = c["ids"][0]
        s0, s1 = c["span"]
        f0, f1 = int(round(s0 * fps)), min(int(round(s1 * fps)), len(F))
        flags, motion, prev = [], [], None
        bucket, bt = [], s0
        # the dancer's clothes over the clip (the tracker can slip onto someone passing in front)
        import cv2
        hx = [p["hist"] for f in range(f0, f1) for p in F[f] if root.get(p["id"], p["id"]) == who and p.get("hist") and p["conf"] > 0.5]
        clip_hist = cc.hist_of(hx[:: max(1, len(hx) // 40)]) if hx else None
        for f in range(f0, f1):
            people = F[f]
            me = [p for p in people if root.get(p["id"], p["id"]) == who]
            t = f / fps
            if not me:
                flags.append((t, 1.0, "lost"))
                prev = None
                continue
            p = max(me, key=lambda q: q["conf"])
            b = p["box"]
            area = max((b[2] - b[0]) * (b[3] - b[1]), 1)
            occ = 0.0
            for q in people:
                if q is p or root.get(q["id"], q["id"]) == who:
                    continue
                occ = max(occ, inter(b, q["box"]) / area)
            kp = p["kp"]
            conf = sum(kp[i][2] for i in BODY) / len(BODY)
            app = 0.0
            if clip_hist is not None and p.get("hist"):
                h1 = cc.hist_of([p["hist"]])
                if h1 is not None:
                    app = cv2.compareHist(clip_hist, h1, cv2.HISTCMP_BHATTACHARYYA)
            if occ > 0.45 or conf < 0.45 or app > 0.5:
                flags.append((t, max(occ, app), "overlap %.2f conf %.2f clothes %.2f" % (occ, conf, app)))
            # body-normalised keypoint speed
            hip = ((kp[11][0] + kp[12][0]) / 2, (kp[11][1] + kp[12][1]) / 2)
            sho = ((kp[5][0] + kp[6][0]) / 2, (kp[5][1] + kp[6][1]) / 2)
            torso = max(math.dist(hip, sho), 1)
            pts = [((kp[i][0] - hip[0]) / torso, (kp[i][1] - hip[1]) / torso) for i in BODY]
            if prev is not None:
                bucket.append(sum(math.dist(a, b2) for a, b2 in zip(pts, prev)) / len(BODY) * fps)
            prev = pts
            if t - bt >= 0.5:
                motion.append((bt - s0, sum(bucket) / max(len(bucket), 1)))
                bucket, bt = [], t
        # group flagged frames into stretches (gaps up to 0.15 s), keep those 0.1 s or longer
        runs, cur = [], None
        for t, occ, why in flags:
            if cur and t - cur[1] <= 0.15:
                cur[1] = t
                cur[2] = max(cur[2], occ)
                cur[3] += 1
            else:
                if cur:
                    runs.append(cur)
                cur = [t, t, occ, 1]
        if cur:
            runs.append(cur)
        runs = [r for r in runs if r[1] - r[0] >= 0.1]
        out.append((name, "", [(round(r[0] - s0, 2), round(r[1] - s0, 2), round(r[2], 2)) for r in runs], motion))
    return out


if __name__ == "__main__":
    for folder in sys.argv[1:]:
        print("##", os.path.basename(folder))
        for name, note, runs, motion in scan(folder):
            if note:
                print(name, note)
                continue
            hid = " ".join("%.2f-%.2f(%.2f)" % r for r in runs) or "-"
            still = " ".join("%.1f" % m[0] for m in motion if m[1] < 0.35)
            print("%s hidden %s | still %s" % (name, hid, still or "-"))
        sys.stdout.flush()
