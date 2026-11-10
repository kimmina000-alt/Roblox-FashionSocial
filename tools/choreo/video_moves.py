"""CHOREO_REVIEW.md 3-2 / 3-3 / 3-4 / 3-5 / 3-6 / 3-7: what the centre dancer of each centercut clip does, every 0.2 s,
in body units, to compare with the capture (tools/choreo/capture_moves.lua).

python -I video_moves.py <centercut folder> [clip names, e.g. 7.mp4,8.mp4] [--beats <video or audio file>]

One line per clip:  <clip> <t>:<Lw>,<Rw>,<Le>,<Re>,<Lk>,<Rk>,<lean>,<mot>,<flags>;...
  Lw / Rw  wrist height over the hip, in torso lengths (shoulder-hip distance)
  Le / Re  elbow angle, degrees (180 = straight)
  Lk / Rk  knee angle, degrees
  lean     shoulder line vs hip line tilt to the side on screen, degrees (+ = the dancer's left side down)
  mot      body-normalised keypoint speed (per second) = 3-2 movement
  flags    L = lying / on the floor (box wider than tall, or hips at ankle height), Cl / Cr = that hand at the face
Sides are the dancer's own (image right = dancer's left on a front-facing video). '-' = not seen.
--beats adds a line: beats <bpm> <first beat s> <period s> (3-6), from the sound's onsets (ffmpeg needed)."""
import json, sys, os, math, subprocess
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "centercut"))
sys.path.insert(1, r"D:\Roblox\Roblox-FashionSocial\tools\choreo\centercut")  # (centercut.py is not committed: the main folder's copy)
import centercut as cc

L_SHO, R_SHO, L_ELB, R_ELB, L_WRI, R_WRI, L_HIP, R_HIP, L_KNE, R_KNE, L_ANK, R_ANK, NOSE = 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 0


def ang(a, b, c):
    v1, v2 = (a[0] - b[0], a[1] - b[1]), (c[0] - b[0], c[1] - b[1])
    n = math.hypot(*v1) * math.hypot(*v2)
    if n < 1e-6:
        return None
    return math.degrees(math.acos(max(-1, min(1, (v1[0] * v2[0] + v1[1] * v2[1]) / n))))


def ok(k, i, c=0.35):
    return k[i][2] >= c


def measure(p):
    k, b = p["kp"], p["box"]
    if not (ok(k, L_SHO) and ok(k, R_SHO) and ok(k, L_HIP) and ok(k, R_HIP)):
        return None
    sho = ((k[L_SHO][0] + k[R_SHO][0]) / 2, (k[L_SHO][1] + k[R_SHO][1]) / 2)
    hip = ((k[L_HIP][0] + k[R_HIP][0]) / 2, (k[L_HIP][1] + k[R_HIP][1]) / 2)
    torso = max(math.dist(sho, hip), 1)
    out = {}
    for s, (S, E, W, H, K, A) in {"L": (L_SHO, L_ELB, L_WRI, L_HIP, L_KNE, L_ANK), "R": (R_SHO, R_ELB, R_WRI, R_HIP, R_KNE, R_ANK)}.items():
        out[s + "w"] = (hip[1] - k[W][1]) / torso if ok(k, W) else None
        out[s + "e"] = ang(k[S], k[E], k[W]) if ok(k, S) and ok(k, E) and ok(k, W) else None
        out[s + "k"] = ang(k[H], k[K], k[A]) if ok(k, H) and ok(k, K) and ok(k, A) else None
        out["C" + s.lower()] = ok(k, W) and ok(k, NOSE) and math.dist(k[W][:2], k[NOSE][:2]) < 0.4 * torso
    # tilt of the shoulder line against the hip line (screen)
    a1 = math.degrees(math.atan2(k[L_SHO][1] - k[R_SHO][1], k[L_SHO][0] - k[R_SHO][0]))
    a2 = math.degrees(math.atan2(k[L_HIP][1] - k[R_HIP][1], k[L_HIP][0] - k[R_HIP][0]))
    out["lean"] = (a1 - a2 + 180) % 360 - 180
    w, h = b[2] - b[0], b[3] - b[1]
    ank = [k[i][1] for i in (L_ANK, R_ANK) if ok(k, i)]
    out["lying"] = w > h * 1.05 or (ank and (min(ank) - hip[1]) < 0.35 * torso)
    out["pts"] = [((k[i][0] - hip[0]) / torso, (k[i][1] - hip[1]) / torso) for i in range(5, 17)]
    return out


def fmt(v, nd=1):
    return "-" if v is None else ("%." + str(nd) + "f") % v


def clips(folder, names):
    T = json.load(open(os.path.join(folder, "tracks.json"), encoding="utf-8"))
    C = json.load(open(os.path.join(folder, "clips.json"), encoding="utf-8"))
    fps, F = T["meta"]["fps"], T["frames"]
    root = cc.stitch_ids(F, fps)
    for name in sorted(C, key=lambda n: int(n.split(".")[0])):
        if names and name not in names:
            continue
        c = C[name]
        if len(c.get("ids", [])) != 1:
            print(name, "several ids, skipped")
            continue
        who, (s0, s1) = c["ids"][0], c["span"]
        items, prev, prevt = [], None, None
        t = s0
        while t < s1 - 0.05:
            f = int(round(t * fps))
            if f >= len(F):
                break
            me = [p for p in F[f] if root.get(p["id"], p["id"]) == who]
            m = measure(max(me, key=lambda q: q["conf"])) if me else None
            if m is None:
                items.append("%.1f:-" % (t - s0))
                prev = None
            else:
                mot = None
                if prev is not None:
                    mot = sum(math.dist(a, b) for a, b in zip(m["pts"], prev)) / 12 / (t - prevt)
                prev, prevt = m["pts"], t
                flags = ("L" if m["lying"] else "") + ("Cl" if m["Cl"] else "") + ("Cr" if m["Cr"] else "")
                items.append("%.1f:%s,%s,%s,%s,%s,%s,%s,%s,%s" % (t - s0, fmt(m["Lw"], 2), fmt(m["Rw"], 2), fmt(m["Le"], 0), fmt(m["Re"], 0),
                                                                   fmt(m["Lk"], 0), fmt(m["Rk"], 0), fmt(m["lean"], 0), fmt(mot, 2), flags))
            t += 0.2
        print(name, ";".join(items))
        sys.stdout.flush()


def beats(path):
    """Tempo and beat phase from onsets (spectral flux of the sound)."""
    import numpy as np
    sr = 11025
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "s16le", "-"], capture_output=True).stdout
    x = np.frombuffer(raw, np.int16).astype(np.float32) / 32768
    hop, win = 256, 1024
    frames = 1 + (len(x) - win) // hop
    spec = np.abs(np.fft.rfft(np.stack([x[i * hop:i * hop + win] * np.hanning(win) for i in range(frames)]), axis=1))
    flux = np.maximum(np.diff(np.log1p(spec), axis=0), 0).sum(axis=1)
    flux = (flux - flux.mean()) / (flux.std() + 1e-9)
    fr = sr / hop
    best = None
    for bpm in np.arange(70, 181, 0.25):
        period = 60 / bpm * fr
        ac = sum(flux[int(i * period + 0.5):].dot(flux[:len(flux) - int(i * period + 0.5)]) for i in (1, 2, 4)) / len(flux)
        if best is None or ac > best[0]:
            best = (ac, bpm)
    bpm = best[1]
    period = 60 / bpm
    phases = np.linspace(0, period, 50, endpoint=False)
    score = [flux[np.clip(((np.arange(0, len(flux) / fr - period, period) + ph) * fr).astype(int), 0, len(flux) - 1)].sum() for ph in phases]
    print("beats %.2f %.3f %.4f" % (bpm, phases[int(np.argmax(score))], period))


if __name__ == "__main__":
    args = sys.argv[1:]
    bf = None
    if "--beats" in args:
        i = args.index("--beats")
        bf = args[i + 1]
        del args[i:i + 2]
    folder = args[0]
    names = set(args[1].split(",")) if len(args) > 1 else None
    clips(folder, names)
    if bf:
        beats(bf)
