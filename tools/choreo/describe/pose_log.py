"""Studio log -> game pose json (pose_common.py format), from the lines pose_record.lua printed (D-1863).

python pose_log.py <tag> --out game.json [--log <Studio log file>]

Takes the last recording with that tag in the newest Studio log that has one (%LOCALAPPDATA%/Roblox/logs)."""
import argparse, glob, json, math, os, sys

NAMES = None


def find_log(tag):
    files = sorted(glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs", "*Studio*.log")),
                   key=os.path.getmtime, reverse=True)
    key = "POSEREC|%s|BEGIN" % tag
    for f in files[:12]:
        with open(f, encoding="utf-8", errors="replace") as fh:
            if key in fh.read():
                return f
    raise SystemExit("no recording '%s' in the newest Studio logs" % tag)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tag")
    ap.add_argument("--out", required=True)
    ap.add_argument("--log")
    a = ap.parse_args()
    path = a.log or find_log(a.tag)
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    pre = "POSEREC|%s|" % a.tag
    start = max(i for i, l in enumerate(lines) if pre + "BEGIN" in l)
    names = lines[start].split(pre + "BEGIN|")[1].split("|")[0].split(",")
    raw = []
    ended = False
    for l in lines[start + 1:]:
        if pre not in l:
            continue
        body = l.split(pre, 1)[1]
        if body.startswith("END") or body.startswith("ERROR"):
            ended = True
            if body.startswith("ERROR"):
                print("recording error:", body, file=sys.stderr)
            break
        if body.startswith("BEGIN"):
            break
        t, rest = body.split("|", 1)
        groups = rest.split(";")
        num = lambda g: [float(x) for x in g.split(",")] if g and g != "," else None
        P = {n: num(groups[i]) for i, n in enumerate(names)}
        k = len(names)
        V = {"lhd": num(groups[k]), "rhd": num(groups[k + 1]), "lpn": num(groups[k + 2]), "rpn": num(groups[k + 3])}
        lf, rf = num(groups[k + 4])
        wst = num(groups[k + 5]) if len(groups) > k + 5 else None  # (D-1950: waist joint move x, y, z + arch degrees)
        raw.append((float(t), P, V, lf, rf, wst))
    if not raw:
        raise SystemExit("recording '%s' has no samples yet" % a.tag)
    if not ended:
        print("(still recording: %d samples so far)" % len(raw), file=sys.stderr)
    mid = lambda p, q: [(p[i] + q[i]) / 2 for i in range(3)]
    torsos = sorted(math.dist(mid(P["lsho"], P["rsho"]), mid(P["lhip"], P["rhip"])) for _, P, _, _, _, _ in raw)
    torso = torsos[len(torsos) // 2]
    ts = [r[0] for r in raw]
    feet = [min(r[3], r[4]) for r in raw]
    samples = []
    h0 = None
    for i, (t, P, V, lf, rf, wst) in enumerate(raw):
        seg = [feet[j] for j in range(len(raw)) if abs(ts[j] - t) <= 2.0]
        floor = min(seg)
        hc = mid(P["lhip"], P["rhip"])
        if h0 is None:
            h0 = hc
        h = {n: round((P[n][1] - floor) / torso, 3) for n in ("lwri", "rwri", "lkne", "rkne") if P.get(n)}
        h["lank"], h["rank"] = round((lf - floor) / torso, 3), round((rf - floor) / torso, 3)
        h["ltoe"], h["rtoe"] = round((P["ltoe"][1] - floor) / torso, 3), round((P["rtoe"][1] - floor) / torso, 3)
        h["hip"] = round((hc[1] - floor) / torso, 3)
        samples.append({
            "t": round(t, 3),
            "p": {n: [round(v - c, 4) for v, c in zip(xyz, hc)] for n, xyz in P.items() if xyz},
            "h": h,
            "tr": [round((hc[0] - h0[0]) / torso, 3), round((hc[2] - h0[2]) / torso, 3)],
            "hd": {"L": V["lhd"], "R": V["rhd"]},
            "pn": {"L": V["lpn"], "R": V["rpn"]},
        })
        if wst:
            # forward (the joint's -z) and up in torso lengths, arch in degrees (+ = chest tipped back)
            samples[-1]["waist"] = [round(-wst[2] / torso, 3), round(wst[1] / torso, 3), wst[3]]
    json.dump({"source": "game", "tag": a.tag, "log": path, "samples": samples}, open(a.out, "w", encoding="utf-8"))
    print("wrote %s: %d samples, %.2f-%.2f s (torso %.2f studs)" % (a.out, len(samples), ts[0], ts[-1], torso))


if __name__ == "__main__":
    main()
