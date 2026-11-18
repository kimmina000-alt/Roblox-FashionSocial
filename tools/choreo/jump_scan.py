# Jumps of the centre dancer: both ankles leave their ground line together (centercut tracks.json)
import json, sys, os, math
sys.path.insert(0, r"D:\Roblox\Roblox-FashionSocial\tools\choreo\centercut")
import centercut as cc
folder = sys.argv[1]
T = json.load(open(os.path.join(folder, "tracks.json"), encoding="utf-8"))
C = json.load(open(os.path.join(folder, "clips.json"), encoding="utf-8"))
fps, F = T["meta"]["fps"], T["frames"]
root = cc.stitch_ids(F, fps)
LS, RS, LH, RH, LA, RA = 5, 6, 11, 12, 15, 16
for name in sorted(C, key=lambda n: int(n.split(".")[0])):
    c = C[name]
    if len(c.get("ids", [])) != 1: continue
    who, (s0, s1) = c["ids"][0], c["span"]
    rows = []
    for f in range(int(s0 * fps), min(int(s1 * fps), len(F))):
        me = [p for p in F[f] if root.get(p["id"], p["id"]) == who]
        if not me: rows.append(None); continue
        k = max(me, key=lambda q: q["conf"])["kp"]
        if min(k[i][2] for i in (LS, RS, LH, RH, LA, RA)) < 0.3: rows.append(None); continue
        torso = math.dist(((k[LS][0]+k[RS][0])/2, (k[LS][1]+k[RS][1])/2), ((k[LH][0]+k[RH][0])/2, (k[LH][1]+k[RH][1])/2))
        rows.append((f / fps - s0, k[LA][1], k[RA][1], (k[LH][1]+k[RH][1])/2, torso))
    W = int(fps * 0.8)
    out = []
    for i, r in enumerate(rows):
        if r is None: continue
        win = [q for q in rows[max(0, i-W):i+W] if q]
        gL = max(q[1] for q in win); gR = max(q[2] for q in win); gH = sorted(q[3] for q in win)[len(win)*3//4]
        up = min(gL - r[1], gR - r[2]) / r[4]
        hu = (gH - r[3]) / r[4]
        if up > 0.10 and hu > 0.08: out.append((r[0], up, hu))
    # group
    groups = []
    for t, up, hu in out:
        if groups and t - groups[-1][1] < 0.12: groups[-1][1] = t; groups[-1][2] = max(groups[-1][2], up); groups[-1][3] = max(groups[-1][3], hu)
        else: groups.append([t, t, up, hu])
    print(name, " ".join("%.2f-%.2f(feet %.2f hip %.2f)" % tuple(g) for g in groups if g[1] - g[0] >= 0.06))
