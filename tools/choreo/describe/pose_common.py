"""Shared pose format, features and Korean phrases for the video and the game (D-1863, README.md).

Pose json (pose_video.py / pose_log.py write it):
  {"source": "video" | "game", "step": 0.05, "samples": [
     {"t": song seconds,
      "p": {name: [x, y, z]}   body points round the hip centre; x = viewer's right, y = up, z = toward the viewer
      "h": {name: height}      height over the floor in torso lengths (lwri rwri lank rank lkne rkne ltoe rtoe hip)
      "tr": [x, z]             travel since the start in torso lengths (x = viewer's right, z = toward the viewer)
      "hd": {"L": v, "R": v}   hand direction (wrist -> knuckles)
      "pn": {"L": v, "R": v}   palm normal (out of the palm)
      "img": {...}, "vt": video seconds   (video only, for the picture sheets)}]}
Sides are the dancer's own (L = the dancer's left hand).
"""
import math

NAMES = ["nose", "lear", "rear", "lsho", "rsho", "lelb", "relb", "lwri", "rwri", "lhand", "rhand",
         "lhip", "rhip", "lkne", "rkne", "lank", "rank", "ltoe", "rtoe"]
SIDE = {"L": "왼", "R": "오른"}


# ---------- small vector helpers ----------
def sub(a, b): return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
def add(a, b): return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
def mul(a, k): return [a[0] * k, a[1] * k, a[2] * k]
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def norm(a): return math.sqrt(dot(a, a))
def unit(a):
    n = norm(a)
    return [a[0] / n, a[1] / n, a[2] / n] if n > 1e-9 else [0.0, 0.0, 0.0]
def mid(a, b): return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2]
def angle(a, b):
    n = norm(a) * norm(b)
    return math.degrees(math.acos(max(-1.0, min(1.0, dot(a, b) / n)))) if n > 1e-9 else None
def wrap(a): return (a + 180) % 360 - 180


def mirror_samples(samples):
    """Left-right mirror (a mirrored practice video against a capture made from the plain one)."""
    sw = lambda n: ("r" + n[1:]) if n.startswith("l") else (("l" + n[1:]) if n.startswith("r") else n)
    out = []
    for s in samples:
        m = dict(s)
        if "p" not in s:
            out.append(m)
            continue
        m["p"] = {sw(k): [-v[0], v[1], v[2]] for k, v in s["p"].items()}
        m["h"] = {sw(k): v for k, v in s.get("h", {}).items()}
        if s.get("tr"):
            m["tr"] = [-s["tr"][0], s["tr"][1]]
        for key in ("hd", "pn"):
            if s.get(key):
                m[key] = {("R" if k == "L" else "L"): ([-v[0], v[1], v[2]] if key == "hd" else [v[0], -v[1], -v[2]])
                          for k, v in s[key].items() if v}
        out.append(m)
    return out


# ---------- per-sample features ----------
def features(s):
    """Body-frame numbers of one sample (torso lengths, degrees). None when the body is not seen."""
    P = s.get("p") or {}
    need = ("lsho", "rsho", "lhip", "rhip")
    if any(n not in P for n in need):
        return None
    hipc, shoc = mid(P["lhip"], P["rhip"]), mid(P["lsho"], P["rsho"])
    torso = norm(sub(shoc, hipc))
    if torso < 1e-6:
        return None
    U = [0.0, 1.0, 0.0]
    hx = sub(P["lhip"], P["rhip"])
    sx = sub(P["lsho"], P["rsho"])
    X = unit([hx[0] + sx[0], 0.0, hx[2] + sx[2]])  # the dancer's left, flat
    F = cross(X, U)                                  # the way the hips face
    B = lambda v: [dot(v, X) / torso, dot(v, U) / torso, dot(v, F) / torso]  # (left, up, forward)
    f = {"torso": torso, "yaw": math.degrees(math.atan2(F[0], F[2]))}       # 0 = facing the viewer, + = turned to the dancer's left
    up = sub(shoc, hipc)
    f["bend"] = math.degrees(math.atan2(dot(up, F), dot(up, U)))   # + = bent forward
    f["side"] = math.degrees(math.atan2(dot(up, X), dot(up, U)))   # + = leaning to the dancer's left
    f["tilt"] = angle(up, U)                                        # how far the torso is off upright, any way
    f["fwd"] = dot(up, F) / torso                                   # + = that way is forward
    f["shoy"] = (shoc[1] - hipc[1]) / torso
    f["shotilt"] = (P["lsho"][1] - P["rsho"][1]) / torso
    f["chest"] = dot(up, F) / torso
    # head
    if all(n in P for n in ("nose", "lear", "rear")):
        ec = mid(P["lear"], P["rear"])
        hf = sub(P["nose"], ec)
        hb = B(hf)
        f["hyaw"] = math.degrees(math.atan2(hb[0], hb[2]))            # + = looking to the dancer's left
        f["hpitch"] = math.degrees(math.atan2(hb[1], math.hypot(hb[0], hb[2])))  # + = up
        el = B(sub(P["lear"], P["rear"]))
        f["hroll"] = math.degrees(math.atan2(el[1], math.hypot(el[0], el[2]))) - math.degrees(math.atan2(B(sx)[1], math.hypot(B(sx)[0], B(sx)[2])))
        f["_ec"] = ec
    for k, l in (("L", "l"), ("R", "r")):
        o = 1 if k == "L" else -1  # outward sign on the left axis
        sh, el, wr = P.get(l + "sho"), P.get(l + "elb"), P.get(l + "wri")
        if el is not None and wr is not None:
            ua, fa = B(sub(el, sh)), B(sub(wr, el))
            arm = B(sub(wr, sh))
            f[k + "elb"] = angle(sub(sh, el), sub(wr, el))
            f[k + "arm"] = [arm[0] * o, arm[1], arm[2]]  # (out, up, forward)
            f[k + "ua"] = [ua[0] * o, ua[1], ua[2]]
            f[k + "fa"] = [fa[0] * o, fa[1], fa[2]]
            w = B(sub(wr, hipc))
            f[k + "wri"] = w
            # wrist bend: + = toward the palm (안쪽), - = toward the back of the hand (밖)
            hd, pn = (s.get("hd") or {}).get(k), (s.get("pn") or {}).get(k)
            if hd and pn:
                fav = unit(sub(wr, el))
                hdu = unit(hd)
                a = angle(fav, hdu)
                perp = sub(hdu, mul(fav, dot(fav, hdu)))
                f[k + "flex"] = a if dot(perp, pn) > 0 else -a
                f[k + "hsrc"] = (s.get("hs") or {}).get(k, "hand" if "hs" not in s else "pose")
                f[k + "pn"] = B(pn)
                f[k + "palmcam"] = pn[2]  # + = the palm faces the viewer
                # palm turn round the forearm axis (for 반바퀴 좌우)
                ref = unit(cross(fav, U)) if abs(dot(fav, U)) < 0.9 else unit(cross(fav, F))
                pp = sub(pn, mul(fav, dot(fav, pn)))
                f[k + "roll"] = math.degrees(math.atan2(dot(cross(ref, pp), fav), dot(ref, pp)))
                f[k + "hdir"] = hdu
                f[k + "fadir"] = fav
        # hand places
        if wr is not None:
            zones = []
            hand = P.get(l + "hand", wr)
            near = lambda q, r: q is not None and norm(sub(hand, q)) / torso < r
            if "_ec" in f:
                top = add(f["_ec"], mul(U, 0.28 * torso))
                if near(top, 0.3) and hand[1] > f["_ec"][1] + 0.1 * torso:
                    zones.append("정수리")
                elif near(P.get("nose"), 0.32):
                    zones.append("얼굴")
                elif near(P.get(l + "ear"), 0.25) or near(P.get(("r" if l == "l" else "l") + "ear"), 0.25):
                    zones.append("귀")
            osl = ("r" if l == "l" else "l") + "sho"
            if not zones and P.get(l + "sho") is not None and near(add(P[l + "sho"], mul(U, 0.12 * torso)), 0.28):
                zones.append("같은 쪽 어깨")
            elif not zones and P.get(osl) is not None and near(add(P[osl], mul(U, 0.12 * torso)), 0.28):
                zones.append("반대 어깨")
            chest = add(sub(shoc, mul(sub(shoc, hipc), 0.25)), mul(F, 0.12 * torso))
            if not zones and near(chest, 0.3):
                zones.append("가슴")
            if not zones and near(add(mid(shoc, hipc), mul(F, 0.15 * torso)), 0.25):
                zones.append("배")
            if not zones and near(P.get(l + "hip"), 0.3):
                zones.append("옆구리")
            ow = P.get(("r" if l == "l" else "l") + "wri")
            if ow is not None and norm(sub(wr, ow)) / torso < 0.28:
                zones.append("양손 모음")
            oe = P.get(("r" if l == "l" else "l") + "elb")
            if oe is not None and ow is not None:
                # hand on the other arm's upper arm / elbow
                osh = P.get(("r" if l == "l" else "l") + "sho")
                for q in (oe, mid(oe, osh) if osh else None):
                    if near(q, 0.22):
                        zones.append("반대팔 위")
                        break
            hh = (s.get("h") or {}).get(l + "wri")
            if hh is not None and hh < 0.22:
                zones.append("바닥")
            f[k + "zone"] = zones
    for k, l in (("L", "l"), ("R", "r")):
        hp, kn, an = P.get(l + "hip"), P.get(l + "kne"), P.get(l + "ank")
        if kn is not None and an is not None:
            f[k + "knee"] = angle(sub(hp, kn), sub(an, kn))
            f[k + "ank"] = B(sub(an, hipc))
    H = s.get("h") or {}
    f["h"] = H
    if "lank" in P and "rank" in P:
        a = B(sub(P["lank"], P["rank"]))
        f["stance"] = math.hypot(a[0], a[2])
    f["tr"] = s.get("tr")
    return f


# ---------- discrete states per sample ----------
def vdir(v):
    """Direction words of an (out, up, forward) vector."""
    n = norm(v)
    if n < 1e-6:
        return "-"
    o, y, fw = v[0] / n, v[1] / n, v[2] / n
    if y > 0.75:
        return "위"
    if y < -0.8:
        return "아래"
    hor = "옆" if abs(o) >= abs(fw) and o > 0 else ("안쪽" if abs(o) >= abs(fw) else ("앞" if fw > 0 else "뒤"))
    if y > 0.4:
        return hor + "·위"
    if y < -0.45:
        return hor + "·아래"
    return hor


def arm_state(f, k):
    e = f.get(k + "elb")
    if e is None:
        return None
    if e > 150:
        return vdir(f[k + "arm"]) + " 쭉 뻗음"
    if 60 <= e <= 120:
        return "직각(위팔 %s, 아래팔 %s)" % (vdir(f[k + "ua"]), vdir(f[k + "fa"]))
    if e < 60:
        return "접음(손 %s)" % vdir(f[k + "arm"])
    return vdir(f[k + "arm"]) + " 굽힘"


def wrist_state(f, k):
    x = f.get(k + "flex")
    if x is None or f.get(k + "hsrc") != "hand":  # (the pose model's finger points are too rough for bends)
        return None
    if x > 35:
        return "안쪽으로 꺾음"
    if x < -35:
        return "밖으로 꺾음"
    if abs(x) < 18:
        return "일자"
    return "살짝"


def head_state(f):
    if "hyaw" not in f:
        return None
    w = []
    if f["hyaw"] > 30:
        w.append("왼쪽 봄")
    elif f["hyaw"] < -30:
        w.append("오른쪽 봄")
    p = f.get("hpitch_rel", 0)
    if p < -20:
        w.append("숙임")
    elif p > 20:
        w.append("듦")
    r = f.get("hroll", 0)
    if r > 15:
        w.append("왼쪽으로 꺾음")
    elif r < -15:
        w.append("오른쪽으로 꺾음")
    return " ".join(w) or "정면"


def trunk_state(f):
    # (the total tilt: on a side view the video's facing is unsure, so forward and sideways mix)
    t = f["tilt"]
    if t > 30 and f["fwd"] > -0.15:
        return "허리 깊이 숙임" if t > 60 else "허리 숙임"
    if t > 18 and f["fwd"] < -0.15:
        return "뒤로 젖힘"
    if f["side"] > 15:
        return "왼쪽으로 기울임"
    if f["side"] < -15:
        return "오른쪽으로 기울임"
    return "바로"


def facing_state(f):
    y = f["yaw"]
    if abs(y) < 40:
        return "정면"
    if abs(y) > 140:
        return "뒤"
    return "몸 오른쪽이 앞(왼쪽으로 돎)" if y > 0 else "몸 왼쪽이 앞(오른쪽으로 돎)"


def leg_state(f, stand_hip):
    H = f["h"]
    w = []
    kl, kr = H.get("lkne"), H.get("rkne")
    if kl is not None and kr is not None and kl < 0.2 and kr < 0.2:
        w.append("양 무릎 꿇음")
    elif kl is not None and kl < 0.2:
        w.append("왼 무릎 꿇음")
    elif kr is not None and kr < 0.2:
        w.append("오른 무릎 꿇음")
    hip = H.get("hip")
    if not w and hip is not None and stand_hip and hip < 0.62 * stand_hip:
        w.append("앉음")
    if not w:
        ks = [f.get("Lknee"), f.get("Rknee")]
        if all(k is not None and k < 135 for k in ks):
            w.append("무릎 굽힘")
    la, ra = H.get("lank"), H.get("rank")
    if la is not None and ra is not None:
        if la > 0.18 and ra > 0.18 and (not stand_hip or hip is None or hip > stand_hip + 0.06):
            w.append("공중")
        elif la > 0.45 and f.get("Lank") and f["Lank"][2] > 0.35:
            w.append("왼발 앞으로 차기")
        elif ra > 0.45 and f.get("Rank") and f["Rank"][2] > 0.35:
            w.append("오른발 앞으로 차기")
        elif la > 0.25:
            w.append("왼발 듦")
        elif ra > 0.25:
            w.append("오른발 듦")
    if f.get("stance", 0) > 1.25:
        w.append("다리 벌림")
    return " ".join(w) or "섬"


# ---------- whole-take analysis ----------
def _smooth_series(vals, k_med=5, k_avg=3):
    """Median (kills single wrong frames) then a short mean, on a list of numbers or None."""
    n = len(vals)
    med = []
    for i in range(n):
        seg = sorted(v for v in vals[max(0, i - k_med // 2):i + k_med // 2 + 1] if v is not None)
        med.append(seg[len(seg) // 2] if seg and vals[i] is not None else None)
    out = []
    for i in range(n):
        seg = [v for v in med[max(0, i - k_avg // 2):i + k_avg // 2 + 1] if v is not None]
        out.append(sum(seg) / len(seg) if seg and med[i] is not None else None)
    return out


def smooth(samples):
    """Every point, height, travel and hand vector smoothed over about 0.15-0.25 s (MediaPipe jitters)."""
    out = [dict(s) for s in samples]
    for key in ("p", "hd", "pn"):
        names = set()
        for s in samples:
            names.update((s.get(key) or {}).keys())
        for n in names:
            cols = []
            for c in range(3):
                cols.append(_smooth_series([((s.get(key) or {}).get(n) or [None] * 3)[c] for s in samples]))
            for i, o in enumerate(out):
                if cols[0][i] is not None:
                    o[key] = dict(o.get(key) or {})
                    o[key][n] = [cols[0][i], cols[1][i], cols[2][i]]
    names = set()
    for s in samples:
        names.update((s.get("h") or {}).keys())
    for n in names:
        col = _smooth_series([(s.get("h") or {}).get(n) for s in samples], 3, 3)
        for i, o in enumerate(out):
            if col[i] is not None:
                o["h"] = dict(o.get("h") or {})
                o["h"][n] = col[i]
    for c in range(2):
        col = _smooth_series([(s.get("tr") or [None, None])[c] for s in samples], 5, 5)
        for i, o in enumerate(out):
            if col[i] is not None and o.get("tr"):
                o["tr"] = list(o["tr"])
                o["tr"][c] = col[i]
    return out


def analyse(samples):
    """Features for every sample plus the take's own baselines."""
    F = [features(s) for s in smooth(samples)]
    good = [f for f in F if f]
    if not good:
        return F
    ps = sorted(f["hpitch"] for f in good if "hpitch" in f)
    pmed = ps[len(ps) // 2] if ps else 0
    hips = sorted(f["h"].get("hip") for f in good if f["h"].get("hip") is not None)
    stand = hips[int(len(hips) * 0.8)] if hips else None
    for f in good:
        if "hpitch" in f:
            f["hpitch_rel"] = f["hpitch"] - pmed
        f["_stand"] = stand
    return F


def states(f):
    if not f:
        return {}
    return {"L팔": arm_state(f, "L"), "R팔": arm_state(f, "R"),
            "L손목": wrist_state(f, "L"), "R손목": wrist_state(f, "R"),
            "L손": " ".join(f.get("Lzone") or []) or "-", "R손": " ".join(f.get("Rzone") or []) or "-",
            "고개": head_state(f), "허리": trunk_state(f), "방향": facing_state(f), "다리": leg_state(f, f.get("_stand"))}


def label(ch):
    return (SIDE[ch[0]] + ch[1:]) if ch[0] in SIDE else ch


def runs(ts, vals, min_len):
    """[(t0, t1, value)] runs; runs shorter than min_len are given to the neighbour (no flicker)."""
    out = []
    for t, v in zip(ts, vals):
        if out and out[-1][2] == v:
            out[-1][1] = t
        else:
            out.append([t, t, v])
    step = (ts[1] - ts[0]) if len(ts) > 1 else 0.05
    changed = True
    while changed and len(out) > 1:
        changed = False
        for i, r in enumerate(out):
            if r[1] - r[0] + step < min_len:
                j = i - 1 if i > 0 else i + 1
                if i > 0 and i + 1 < len(out) and (out[i + 1][1] - out[i + 1][0]) > (out[i - 1][1] - out[i - 1][0]):
                    j = i + 1
                if j < i:
                    out[j][1] = r[1]
                else:
                    out[j][0] = r[0]
                del out[i]
                if 0 < i < len(out) and out[i - 1][2] == out[i][2]:
                    out[i - 1][1] = out[i][1]
                    del out[i]
                changed = True
                break
    return [(r[0], r[1] + step, r[2]) for r in out]


# ---------- motion events ----------
def unwrap(vals):
    out, prev, acc = [], None, None
    for v in vals:
        if v is None:
            out.append(None)
            continue
        acc = v if acc is None else acc + wrap(v - prev)
        prev = v
        out.append(acc)
    return out


def swings(xs, amp):
    """Number of direction changes bigger than amp (a zig-zag count)."""
    xs = [x for x in xs if x is not None]
    if len(xs) < 3:
        return 0
    n, last, ext = 0, None, xs[0]
    for q in xs[1:]:
        if last is None:
            if abs(q - ext) > amp:
                last = 1 if q > ext else -1
                ext = q
        elif (q - ext) * last > 0:
            ext = q
        elif abs(q - ext) > amp:
            n += 1
            last = -last
            ext = q
    return n


def merge(evs, gap):
    evs.sort(key=lambda e: (e[2], e[0]))
    out = []
    for e in evs:
        if out and out[-1][2] == e[2] and e[0] <= out[-1][1] + gap:
            out[-1][1] = max(out[-1][1], e[1])
            if len(e) > 3:
                out[-1][3] = e[3] if abs(e[3]) > abs(out[-1][3]) else out[-1][3]
        else:
            out.append(list(e))
    return out


def events(ts, F):
    """Moves over time: turns, jumps, arm / wrist circles, palm flips, waves, shoulder bounces, chest pops,
    claps, walking. [(t0, t1, text)]"""
    n = len(ts)
    step = (ts[1] - ts[0]) if n > 1 else 0.05
    ev = []
    # turns: yaw speed over 100°/s, summed
    yaw = unwrap([f["yaw"] if f else None for f in F])
    i = 0
    while i < n:
        if yaw[i] is None:
            i += 1
            continue
        j = i
        while j + 1 < n and yaw[j + 1] is not None and abs(yaw[j + 1] - yaw[j]) / step > 100 and \
                (j == i or (yaw[j + 1] - yaw[j]) * (yaw[i + 1] - yaw[i]) > 0):
            j += 1
        if j > i:
            tot = yaw[j] - yaw[i]
            if abs(tot) >= 70:
                ev.append([ts[i], ts[j] + step, "회전", tot])
            i = j
        i += 1
    ev = merge(ev, 0.15)
    out = []
    for t0, t1, _, tot in ev:
        laps = abs(tot) / 360
        amount = "%d°" % abs(round(tot / 10) * 10)
        if 0.4 <= laps < 0.65:
            amount = "반 바퀴"
        elif 0.85 <= laps < 1.2:
            amount = "한 바퀴"
        elif 1.8 <= laps < 2.2:
            amount = "두 바퀴"
        out.append((t0, t1, "%s으로 %s 회전 (%.1f초)" % ("왼쪽" if tot > 0 else "오른쪽", amount, t1 - t0)))
    win = max(3, round(1.0 / step))
    # windows: arm circles, wrist circles, half turns, waves
    for k in ("L", "R"):
        side = SIDE[k]
        for name, get, need, text in (
                ("팔 원(앞)", lambda f: math.degrees(math.atan2(f[k + "arm"][1], f[k + "arm"][0])) if f and f.get(k + "arm") and math.hypot(f[k + "arm"][0], f[k + "arm"][1]) > 0.35 else None, 300, "%s팔 크게 돌리기"),
                ("팔 원(옆)", lambda f: math.degrees(math.atan2(f[k + "arm"][1], f[k + "arm"][2])) if f and f.get(k + "arm") and math.hypot(f[k + "arm"][1], f[k + "arm"][2]) > 0.35 else None, 300, "%s팔 크게 돌리기"),
        ):
            a = unwrap([get(f) for f in F])
            evs = []
            for s0 in range(0, n - win):
                seg = [x for x in a[s0:s0 + round(1.5 / step)] if x is not None]
                if len(seg) > 5 and abs(seg[-1] - seg[0]) >= need and swings(seg, 60) == 0:
                    evs.append([ts[s0], ts[min(n - 1, s0 + round(1.5 / step))], "c", seg[-1] - seg[0]])
            for t0, t1, _, tot in merge(evs, 0.1):
                laps = max(1, round(abs(tot) / 360))
                out.append((t0, t1, (text % side) + (" %d바퀴" % laps)))
        # wrist circles: the hand round the forearm axis
        hc = []
        for f in F:
            if f and f.get(k + "hdir") and f.get(k + "fadir"):
                fa, hd = f[k + "fadir"], f[k + "hdir"]
                perp = sub(hd, mul(fa, dot(fa, hd)))
                if norm(perp) > 0.25:
                    ref = unit(cross(fa, [0, 1, 0])) if abs(fa[1]) < 0.9 else unit(cross(fa, [0, 0, 1]))
                    hc.append(math.degrees(math.atan2(dot(cross(ref, perp), fa), dot(ref, perp))))
                    continue
            hc.append(None)
        hc = unwrap(hc)
        evs = []
        for s0 in range(0, n - win):
            seg = [x for x in hc[s0:s0 + round(1.2 / step)] if x is not None]
            if len(seg) > 6 and abs(seg[-1] - seg[0]) >= 300:
                evs.append([ts[s0], ts[min(n - 1, s0 + round(1.2 / step))], "w", seg[-1] - seg[0]])
        for t0, t1, _, tot in merge(evs, 0.1):
            out.append((t0, t1, "%s손 손목 돌리기 %d바퀴" % (side, max(1, round(abs(tot) / 360)))))
        # half turns left and right (palm round the forearm), palm flips
        ro = [f.get(k + "roll") if f else None for f in F]
        evs = []
        for s0 in range(0, n - win):
            seg = ro[s0:s0 + win]
            if sum(1 for x in seg if x is not None) > win * 0.6 and swings(unwrap(seg), 80) >= 3:
                evs.append([ts[s0], ts[min(n - 1, s0 + win)], "r"])
        for t0, t1, _ in merge(evs, 0.1):
            out.append((t0, t1, "%s손 반바퀴씩 좌우로 돌리기" % side))
        # waves / shakes: the wrist going side to side or up and down
        for axis, word in ((0, "좌우로"), (1, "위아래로")):
            xs = [f[k + "wri"][axis] if f and f.get(k + "wri") else None for f in F]
            evs = []
            w12 = round(1.2 / step)
            for s0 in range(0, n - w12):
                seg = xs[s0:s0 + w12]
                c = swings(seg, 0.2)
                if c >= 3:
                        evs.append([ts[s0], ts[min(n - 1, s0 + w12)], "s", c])
            for t0, t1, _, c in merge(evs, 0.1):
                fast = c / max(t1 - t0, 0.3) > 4
                out.append((t0, t1, "%s손 %s %s" % (side, word, "털기" if fast else "흔들기")))
    # shoulders up and down
    for key, word, amp in (("shoy", "어깨 들썩들썩", 0.05), ("shotilt", "어깨 한쪽씩 위아래", 0.09), ("chest", "가슴 튕기기", 0.09)):
        xs = [f[key] if f else None for f in F]
        evs = []
        for s0 in range(0, n - win):
            if swings(xs[s0:s0 + win], amp) >= 3:
                evs.append([ts[s0], ts[min(n - 1, s0 + win)], key])
        for t0, t1, _ in merge(evs, 0.1):
            out.append((t0, t1, word))
    # claps: the wrists meet and part again and again
    d = [norm(sub(mul(f["Lwri"], 1), f["Rwri"])) if f and f.get("Lwri") and f.get("Rwri") else None for f in F]
    evs = []
    for s0 in range(0, n - win):
        seg = d[s0:s0 + win]
        if swings(seg, 0.18) >= 2 and min((x for x in seg if x is not None), default=9) < 0.25:
            evs.append([ts[s0], ts[min(n - 1, s0 + win)], "clap"])
    for t0, t1, _ in merge(evs, 0.1):
        out.append((t0, t1, "손뼉/손바닥 부딪히기"))
    # jumps: both feet up
    stand = next((f["_stand"] for f in F if f and f.get("_stand")), None)
    air = [bool(f) and f["h"].get("lank") is not None and f["h"].get("rank") is not None and
           f["h"]["lank"] > 0.15 and f["h"]["rank"] > 0.15 and
           (stand is None or f["h"].get("hip") is None or f["h"]["hip"] > stand + 0.06) for f in F]
    for t0, t1, v in runs(ts, air, 0.0):
        if v and t1 - t0 >= 0.1:
            hmax = max(min(f["h"]["lank"], f["h"]["rank"]) for t, f in zip(ts, F) if f and t0 <= t < t1 and f["h"].get("lank") is not None and f["h"].get("rank") is not None)
            out.append((t0, t1, "점프 (양발 뜸 %.2f초, 높이 %.2f)" % (t1 - t0, hmax)))
    # walking / travel
    tr = [f["tr"] if f and f.get("tr") else None for f in F]
    s0 = 0
    evs = []
    w = round(0.6 / step)
    for i in range(0, n - w):
        a, b = tr[i], tr[i + w]
        if a and b:
            dx, dz = b[0] - a[0], b[1] - a[1]
            if math.hypot(dx, dz * 0.6) / 0.6 > 0.5:
                if abs(dx) > abs(dz):
                    word = "오른쪽(화면)" if dx > 0 else "왼쪽(화면)"
                else:
                    word = "앞으로" if dz > 0 else "뒤로"
                evs.append([ts[i], ts[i + w], word])
    for t0, t1, word in merge(evs, 0.15):
        out.append((t0, t1, "%s 이동 (걸어감)" % word))
    lift = [None if not f else (f["h"].get("lank", 0) > 0.12) - (f["h"].get("rank", 0) > 0.12) for f in F]
    evs = []
    for i in range(0, n - win):
        seg = [x for x in lift[i:i + win] if x is not None]
        if seg.count(1) >= 2 and seg.count(-1) >= 2 and swings(seg, 1) >= 2:
            moving = tr[i] and tr[i + win - 1] and math.hypot(tr[i + win - 1][0] - tr[i][0], tr[i + win - 1][1] - tr[i][1]) > 0.35
            evs.append([ts[i], ts[i + win], "발 번갈아 듦 (이동)" if moving else "제자리 걸음/스텝"])
    for t0, t1, word in merge(evs, 0.1):
        out.append((t0, t1, word))
    return sorted(out)


def ftime(t):
    sign = "-" if t < 0 else ""
    t = abs(t)
    return "%s%d:%04.1f" % (sign, int(t // 60), t % 60)


def describe(samples, min_len=0.25):
    """Text lines: every state change and every move, in song time."""
    ts = [s["t"] for s in samples]
    F = analyse(samples)
    S = [states(f) for f in F]
    lines = []
    for ch in ("방향", "허리", "다리", "고개", "L팔", "R팔", "L손", "R손", "L손목", "R손목"):
        vals = [s.get(ch) if s else None for s in S]
        for t0, t1, v in runs(ts, vals, min_len):
            if v is None or v in ("-", "살짝"):
                continue
            lines.append((t0, t1, "%s: %s" % (label(ch), v)))
    for t0, t1, txt in events(ts, F):
        lines.append((t0, t1, "★ " + txt))
    lines.sort()
    return ["%s-%s %s" % (ftime(a), ftime(b), txt) for a, b, txt in lines]
