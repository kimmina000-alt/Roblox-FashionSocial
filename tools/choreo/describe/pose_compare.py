"""The original against the game, in Korean lines (D-1863). Called by pose_text.py compare."""
import math, os, subprocess, sys

import pose_common as pc

HINT = {"팔": "팔 모양: pose / amp (ChoreoFixes)", "손목": "bend (§20)", "허리": "pose: UpperTorso / LowerTorso",
        "방향": "spin / turn / faceOffset", "고개": "bend Head", "다리": "pose set / freeze (바닥) · ChoreoJumps (점프)",
        "손": "pose (손 위치)", "멈춤": "replay / 재업로드 / warp", "타이밍": "at / from 조정", "이동": "walk / glide",
        "회전": "spin", "점프": "ChoreoJumps", "버벅": "spin ease / blend / steady"}


def resample(samples, ts, tol):
    out, j = [], 0
    for t in ts:
        while j + 1 < len(samples) and abs(samples[j + 1]["t"] - t) <= abs(samples[j]["t"] - t):
            j += 1
        out.append(samples[j] if samples and abs(samples[j]["t"] - t) <= tol else None)
    return out


def arm_vec(f, k):
    return f.get(k + "arm") if f else None


def score(FV, FG):
    """How alike the arms are (mean cosine of shoulder -> wrist), to pick mirror or not."""
    tot, n = 0.0, 0
    for a, b in zip(FV, FG):
        for k in ("L", "R"):
            u, v = arm_vec(a, k), arm_vec(b, k)
            if u and v and pc.norm(u) > 0.3 and pc.norm(v) > 0.3:
                tot += pc.dot(pc.unit(u), pc.unit(v))
                n += 1
    return tot / n if n else 0


def runs_of(ts, flags, step, min_len, gap=0.15):
    out = []
    for t, f in zip(ts, flags):
        if f:
            if out and t - out[-1][1] <= gap + step:
                out[-1][1] = t
            else:
                out.append([t, t])
    return [(a, b + step) for a, b in out if b + step - a >= min_len]


def majority(vals):
    vals = [v for v in vals if v is not None]
    if not vals:
        return "-"
    return max(set(vals), key=vals.count)


def lag_windows(ts, FV, FG, step):
    """Per 4 s: the shift (s) that makes the game's arms and legs match the video best (+ = the game is late)."""
    out = []
    w = int(4 / step)
    def vec(f):
        if not f:
            return None
        v = []
        for k in ("L", "R"):
            for key in ("arm", "ank"):
                x = f.get(k + key)
                if not x:
                    return None
                v += list(x)
        return v
    V = [vec(f) for f in FV]
    G = [vec(f) for f in FG]
    for s0 in range(0, len(ts) - w, w):
        best = None
        for lag in range(-int(0.6 / step), int(0.6 / step) + 1):
            tot, n = 0.0, 0
            for i in range(s0, s0 + w):
                j = i + lag
                if 0 <= j < len(G) and V[i] and G[j]:
                    tot += math.dist(V[i], G[j])
                    n += 1
            if n > w * 0.5:
                m = tot / n
                if best is None or m < best[0]:
                    best = (m, lag)
        if best:
            zero = None
            tot, n = 0.0, 0
            for i in range(s0, s0 + w):
                if V[i] and G[i]:
                    tot += math.dist(V[i], G[i])
                    n += 1
            zero = tot / n if n else None
            out.append((ts[s0], ts[s0 + w - 1] + step, best[1] * step, best[0], zero))
    return out


def compare(dv, v, dg, g, mirror="auto", min_len=0.3, sheet=None):
    step = dv.get("step", 0.05)
    t0 = max(v[0]["t"], g[0]["t"])
    t1 = min(v[-1]["t"], g[-1]["t"])
    ts = []
    t = t0
    while t <= t1 + 1e-6:
        ts.append(round(t, 3))
        t += step
    V = resample(v, ts, step * 0.6)
    G = resample(g, ts, step * 0.6)
    lines = []
    FG = pc.analyse([s or {"t": t} for s, t in zip(G, ts)])
    FV0 = pc.analyse([s or {"t": t} for s, t in zip(V, ts)])
    use_mirror = mirror == "on"
    if mirror == "auto":
        FV1 = pc.analyse(pc.mirror_samples([s or {"t": t} for s, t in zip(V, ts)]))
        a0, a1 = score(FV0, FG), score(FV1, FG)
        use_mirror = a1 > a0 + 0.05
        lines.append("# 좌우: %s (팔 일치도 그대로 %.2f / 거울 %.2f)" % ("거울로 비교" if use_mirror else "그대로 비교", a0, a1))
    FV = pc.analyse(pc.mirror_samples([s or {"t": t} for s, t in zip(V, ts)])) if use_mirror else FV0
    SV = [pc.states(f) for f in FV]
    SG = [pc.states(f) for f in FG]
    seen = sum(1 for f in FV if f)
    lines.append("# 구간 %s-%s, 원본 인식 %d%% (안 보인 곳은 비교 안 함)" % (pc.ftime(t0), pc.ftime(t1 + step), 100 * seen // max(1, len(ts))))
    found = []  # (t0, t1, part, video text, game text, hint key)

    def add_runs(flags, part, key, vtext, gtext, hint):
        for a, b in runs_of(ts, flags, step, min_len):
            idx = [i for i, t in enumerate(ts) if a <= t < b]
            found.append((a, b, part, majority([vtext(i) for i in idx]), majority([gtext(i) for i in idx]), hint))

    for k in ("L", "R"):
        side = pc.SIDE[k]
        # arms: shoulder -> wrist direction 50°+ apart, or the elbow 55°+ different
        fl = []
        for a, b in zip(FV, FG):
            u, w = arm_vec(a, k), arm_vec(b, k)
            bad = False
            if u and w and pc.norm(u) > 0.25 and pc.norm(w) > 0.25:
                ang = pc.angle(u, w)
                bad = ang is not None and ang > 50
                if not bad and a.get(k + "elb") and b.get(k + "elb"):
                    bad = abs(a[k + "elb"] - b[k + "elb"]) > 55
            fl.append(bad)
        add_runs(fl, side + "팔", k + "팔", lambda i: SV[i].get(k + "팔"), lambda i: SG[i].get(k + "팔"), "팔")
        # wrists: one side bent 35°+ and the two 35°+ apart
        fl = []
        for a, b in zip(FV, FG):
            x, y = (a or {}).get(k + "flex"), (b or {}).get(k + "flex")
            # only where the hand model read the video's hand, and clearly apart (the picture is small: check by eye)
            fl.append(x is not None and y is not None and (a or {}).get(k + "hsrc") == "hand" and abs(x - y) > 45 and max(abs(x), abs(y)) > 45)
        add_runs(fl, side + "손목(그림 확인)", k + "손목",
                 lambda i: "%s(%+d°)" % (SV[i].get(k + "손목"), FV[i][k + "flex"]) if FV[i] and FV[i].get(k + "flex") is not None else None,
                 lambda i: "%s(%+d°)" % (SG[i].get(k + "손목"), FG[i][k + "flex"]) if FG[i] and FG[i].get(k + "flex") is not None else None, "손목")
        # hand places (face, top of the head, ear, chest, floor, hands together, on the other arm)
        fl = []
        for a, b in zip(SV, SG):
            za, zb = a.get(k + "손"), b.get(k + "손")
            fl.append(bool(a) and bool(b) and za not in ("-", None) and za != zb)
        add_runs(fl, side + "손 위치", k + "손", lambda i: SV[i].get(k + "손"), lambda i: SG[i].get(k + "손"), "손")
    # body
    def num_diff(key, thr, part, hint, fmt):
        fl = [bool(a) and bool(b) and a.get(key) is not None and b.get(key) is not None and abs(a[key] - b[key]) > thr for a, b in zip(FV, FG)]
        add_runs(fl, part, key, lambda i: fmt(FV[i], SV[i]), lambda i: fmt(FG[i], SG[i]), hint)
    num_diff("tilt", 22, "허리 숙임", "허리", lambda f, s: "%s %d°" % (s.get("허리"), round(f["tilt"] / 5) * 5) if f else None)
    fl = [bool(a) and bool(b) and a["tilt"] < 30 and b["tilt"] < 30 and abs(a["side"] - b["side"]) > 15 for a, b in zip(FV, FG)]
    add_runs(fl, "허리 옆 기울기", "side", lambda i: "%s %d°" % (SV[i].get("허리"), round(FV[i]["side"] / 5) * 5) if FV[i] else None,
             lambda i: "%s %d°" % (SG[i].get("허리"), round(FG[i]["side"] / 5) * 5) if FG[i] else None, "허리")
    fl = [bool(a) and bool(b) and abs(pc.wrap(a["yaw"] - b["yaw"])) > 50 for a, b in zip(FV, FG)]
    add_runs(fl, "몸 방향", "방향", lambda i: "%s %+d°" % (SV[i].get("방향"), round(FV[i]["yaw"] / 10) * 10) if FV[i] else None,
             lambda i: "%s %+d°" % (SG[i].get("방향"), round(FG[i]["yaw"] / 10) * 10) if FG[i] else None, "방향")
    hold = min_len
    min_len = max(min_len, 0.5)  # (the video's head is the roughest reading: only long differences)
    for key, thr, part in (("hyaw", 40, "고개 좌우"), ("hpitch_rel", 30, "고개 숙임/듦"), ("hroll", 20, "고개 기울기")):
        num_diff(key, thr, part, "고개", lambda f, s: s.get("고개") if f else None)
    min_len = hold
    # legs: kneeling / sitting / in the air / a foot up
    def legword(s):
        x = s.get("다리") or ""
        for w in ("양 무릎 꿇음", "왼 무릎 꿇음", "오른 무릎 꿇음", "앉음", "공중", "앞으로 차기", "발 듦"):
            if w in x:
                return w
        return "섬"
    fl = [bool(a) and bool(b) and legword(a) != legword(b) for a, b in zip(SV, SG)]
    add_runs(fl, "다리", "다리", lambda i: SV[i].get("다리"), lambda i: SG[i].get("다리"), "다리")
    # stalls: the video moves, the game hardly does
    def speed(F):
        out = [None]
        for a, b in zip(F, F[1:]):
            if a and b and all(a.get(k + "wri") and b.get(k + "wri") for k in "LR"):
                d = sum(math.dist(a[k + "wri"], b[k + "wri"]) for k in "LR")
                d += sum(math.dist(a[k + "ank"], b[k + "ank"]) for k in "LR" if a.get(k + "ank") and b.get(k + "ank"))
                out.append(d / step)
            else:
                out.append(None)
        return out
    sv, sg = speed(FV), speed(FG)
    med = sorted(x for x in sg if x)
    gmed = med[len(med) // 2] if med else 1
    # (a held game pose reads about 0: the game's own joints do not jitter like the video's)
    fl = [x is not None and y is not None and ((x > 1.6 and y < max(0.25, gmed / 3)) or (x > 0.7 and y < 0.12)) for x, y in zip(sv, sg)]
    add_runs(fl, "멈춤", "멈춤", lambda i: "움직임 %.1f" % sv[i] if sv[i] else None, lambda i: "거의 멈춤 %.1f" % sg[i] if sg[i] is not None else None, "멈춤")
    # moves (turns, jumps, circles, waves...) in one and not in the other
    EV = pc.events(ts, FV)
    EG = pc.events(ts, FG)
    def kind(txt):
        for w in ("회전", "점프", "크게 돌리기", "손목 돌리기", "반바퀴씩", "흔들기", "털기", "어깨", "가슴", "손뼉", "이동", "제자리", "발 번갈아"):
            if w in txt:
                side = "왼" if txt.startswith("왼") else ("오른" if txt.startswith("오른") else "")
                return side + w
        return txt
    SURE = ("회전", "점프", "크게 돌리기", "손목 돌리기", "이동", "제자리")  # (waves, shoulders, chest pops: too rough to call missing)
    for a, b, txt in EV:
        if not any(w in txt for w in SURE):
            continue
        if not any(kind(t2) == kind(txt) and a2 < b + 0.4 and b2 > a - 0.4 for a2, b2, t2 in EG):
            found.append((a, b, "동작 빠짐", txt, "없음", kind(txt).lstrip("왼오른")))
    for a, b, txt in EG:
        k = kind(txt)
        if any(w in k for w in ("회전", "점프")) and not any(kind(t2) == k and a2 < b + 0.4 and b2 > a - 0.4 for a2, b2, t2 in EV):
            found.append((a, b, "게임에만", "없음", txt, k))
    # turns that stall or go back half way in the game (버벅)
    yaw = pc.unwrap([f["yaw"] if f else None for f in FG])
    for a, b, txt in EG:
        if "회전" in txt:
            seg = [y for t, y in zip(ts, yaw) if a <= t <= b and y is not None]
            back = pc.swings(seg, 15)
            if back:
                found.append((a, b, "회전 버벅", "", "도는 중 %d번 멈칫/역회전" % back, "버벅"))
    # timing
    lagw = lag_windows(ts, FV, FG, step)
    for a, b, lag, best, zero in lagw:
        if abs(lag) >= 0.15 and zero and best < zero * 0.8:
            found.append((a, b, "타이밍", "", "게임이 %.2f초 %s" % (abs(lag), "늦음" if lag > 0 else "빠름"), "타이밍"))
    # camera cuts / zooms of the video (and the centre member changing there): the video's facing, floor and
    # travel are unsure within 0.5 s of one, so those kinds are left out there
    cams = [(s or {}).get("cam") for s in V]
    cut_t = [ts[i] for i in range(1, len(ts)) if cams[i] is not None and cams[i - 1] is not None and cams[i] != cams[i - 1]]
    def near_cut(a, b):
        return any(a - 0.5 <= c <= b + 0.5 for c in cut_t)
    shaky = ("몸 방향", "다리", "동작 빠짐", "게임에만")
    kept = [it for it in found if not (it[2] in shaky and near_cut(it[0], it[1]) and
                                       (it[2] != "동작 빠짐" or any(w in it[3] for w in ("이동", "점프", "회전", "제자리"))))]
    if len(kept) < len(found):
        lines.append("# 카메라 컷 0.5초 안의 몸 방향 · 다리 · 이동 · 점프 · 회전 차이 %d건은 뺌 (컷 %d번)" % (len(found) - len(kept), len(cut_t)))
    found = kept
    found.sort()
    # one memo line per moment: the differences that overlap (or are 0.2 s apart) together
    WEIGHT = {"방향": 3, "회전": 3, "점프": 3, "멈춤": 3, "버벅": 2.5, "타이밍": 2, "이동": 2, "다리": 2, "허리": 2,
              "팔": 1.5, "손": 1.5, "손목": 1, "고개": 0.6}
    groups = []
    for item in found:
        if groups and item[0] <= groups[-1][1] + 0.2 and item[0] - groups[-1][0] < 1.0:
            groups[-1][1] = max(groups[-1][1], item[1])
            groups[-1][2].append(item)
        else:
            groups.append([item[0], item[1], [item]])
    def item_text(it):
        a, b, part, vt, gt, hint = it
        if part in ("동작 빠짐",):
            return "%s 빠짐" % vt
        if part == "게임에만":
            return "게임에만 %s" % gt
        if part in ("회전 버벅", "타이밍"):
            return "%s: %s" % (part, gt)
        return "%s 원본 %s → 게임 %s" % (part, vt, gt)
    def gscore(g):
        return sum((it[1] - it[0]) * WEIGHT.get(next((k for k in WEIGHT if k in it[5] or k in it[2]), ""), 1) for it in g[2])
    for g in groups:
        best = {}
        for it in g[2]:
            key = (it[2], it[3] if it[2] in ("동작 빠짐", "게임에만") else "")
            if key not in best or (it[1] - it[0]) > (best[key][1] - best[key][0]):
                best[key] = it
        g[2] = sorted(best.values())
    def gline(g):
        out = ["%s-%s" % (pc.ftime(g[0]), pc.ftime(g[1]))]
        for it in g[2]:
            h = HINT.get(it[5], "")
            out.append("    %s  %s%s" % (pc.ftime(it[0]), item_text(it), ("   [" + h + "]") if h else ""))
        return "\n".join(out)
    top = sorted(groups, key=gscore, reverse=True)[:25]
    lines.append("")
    lines.append("## 먼저 볼 곳 (크고 오래가는 차이 순 %d곳)" % len(top))
    for g in sorted(top):
        lines.append(gline(g))
    lines.append("")
    lines.append("## 전체 (시간 순 %d곳, 차이 %d건)" % (len(groups), len(found)))
    for g in groups:
        lines.append(gline(g))
    if sheet:
        os.makedirs(sheet, exist_ok=True)
        here = os.path.dirname(os.path.abspath(__file__))
        vj, gj = dv.get("_path"), dg.get("_path")
        if vj and gj:
            for a, b, _ in sorted(top):
                a, b = max(t0, a - 0.2), min(t1, b + 0.2)
                if b - a > 2.4:
                    b = a + 2.4
                out = os.path.join(sheet, "%s_%s.jpg" % (pc.ftime(a).replace(":", "m"), pc.ftime(b).replace(":", "m")))
                subprocess.run([sys.executable, os.path.join(here, "pose_sheet.py"), vj, gj, "--from", str(a), "--to", str(b),
                                "--step", "0.1", "--cols", "12", "--out", out] + (["--mirror"] if use_mirror else []),
                               capture_output=True)
            lines.append("# 그림: %s (%d장; 위 = 원본, 가운데 = 게임, 아래 = 원본 점을 게임식으로 그린 것)" % (sheet, len(top)))
    return lines
