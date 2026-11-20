"""안무 2차 검토: 원본 영상 vs 게임 모션, 다른 시선으로 (D-1890, README.md).

pose_compare.py(D-1863)가 포즈를 '범주 글'로 비교한다면, 이 도구는 같은 두 json을 연속 숫자로 다시 봅니다.
  1. 모양   부위별(왼팔·오른팔·손·다리·몸통·고개) 각도 오차를 0.02초마다. 기준을 넘는 구간 + 어디가 어떻게 다른지
  2. 박자   부위별 지연: 2초 창마다 속도 상관으로 게임이 몇 ms 늦거나 빠른지 (+ = 게임이 늦음)
  3. 끊는 박 원본에서 빠르게 움직이다 딱 멈추는 순간(hit)을 하나하나 찾아 게임 hit과 ms 단위로 짝지음.
            빠진 hit(게임은 흐물흐물), 게임에만 있는 hit, 음악 박에서 얼마나 벗어났는지
  4. 작은 움직임  움직임 양(원본 대비 몇 %), 멈춤, 과함, 무릎 바운스 · 고개 끄덕 · 어깨 들썩의 크기와 박(반대 박 포함)
  5. 방향   몸이 향한 방향 차이 (카메라 각도는 곡 전체 중앙값으로 뺌)
결과: 리포트(글) + 뷰어(html: 원본 영상 위에 게임 뼈대를 겹쳐 보고, 정면 · 옆 · 위 세 시점, 박자 타임라인).

python tools/choreo/review/choreo_review.py <video pose json> <game pose json> --video <원본 mp4> --out <폴더>
       [--title 곡이름] [--mirror auto|on|off] [--from s] [--to s] [--top 40]
  (json = pose_video.py / pose_log.py 결과. 원본 영상은 --video로 꼭 주기: json 안 경로는 한글이 깨질 수 있음)
"""
import argparse, json, math, os, subprocess, sys
import numpy as np
import warnings
warnings.filterwarnings("ignore", category=RuntimeWarning)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "describe"))
import pose_common as pc  # noqa: E402  (NAMES, vdir, ftime)

NAMES = pc.NAMES
NI = {n: i for i, n in enumerate(NAMES)}
DT = 0.02          # analysis grid (s)
VSTEP = 0.04       # viewer grid (s): every 2nd analysis sample
# extra points made from the body points
XP = ["HIP", "SHO", "EAR"]
ALL = NAMES + XP
AI = {n: i for i, n in enumerate(ALL)}

# segment: (name, from, to, group, side) — side +1 / -1 turns the dancer's left axis into "out" for words
SEGS = [
    ("왼 위팔", "lsho", "lelb", "왼팔", 1), ("왼 아래팔", "lelb", "lwri", "왼팔", 1),
    ("오른 위팔", "rsho", "relb", "오른팔", -1), ("오른 아래팔", "relb", "rwri", "오른팔", -1),
    ("왼손", "lwri", "lhand", "왼손", 1), ("오른손", "rwri", "rhand", "오른손", -1),
    ("왼 허벅지", "lhip", "lkne", "왼다리", 1), ("왼 정강이", "lkne", "lank", "왼다리", 1),
    ("오른 허벅지", "rhip", "rkne", "오른다리", -1), ("오른 정강이", "rkne", "rank", "오른다리", -1),
    ("몸통", "HIP", "SHO", "몸통", 1), ("어깨선", "rsho", "lsho", "몸통", 1),
    ("목·고개", "SHO", "EAR", "고개", 1), ("얼굴 방향", "EAR", "nose", "고개", 1),
]
GROUPS = ["왼팔", "오른팔", "왼손", "오른손", "왼다리", "오른다리", "몸통", "고개"]
GSEG = {g: [i for i, s in enumerate(SEGS) if s[3] == g] for g in GROUPS}
THR = {"왼팔": 38, "오른팔": 38, "왼손": 60, "오른손": 60, "왼다리": 32, "오른다리": 32, "몸통": 20, "고개": 32}
# hit detection: peak speed (deg/s, summed over the group's segments) a hit needs
HIT_PEAK = {"왼팔": 260, "오른팔": 260, "왼손": 420, "오른손": 420, "왼다리": 200, "오른다리": 200, "몸통": 110, "고개": 170}
# movement a window needs before "small / stopped" is judged (deg/s)
# size bands (user 2026-11-20, D-1895): jumps, big moves and wrist bends bigger than the video, never broken.
# game / video movement: SMALL under the first, OVER above the second (held a while). Legs follow the video (not enlarged).
SIZE = {"왼팔": (1.0, 1.8), "오른팔": (1.0, 1.8), "몸통": (1.0, 1.8), "고개": (1.0, 1.8),
        "왼다리": (0.45, 1.5), "오른다리": (0.45, 1.5)}
WRIST_OVER, WRIST_BROKEN = 90.0, 105.0   # degrees hand vs forearm in the air; a hand touching the other hand or the body is let off
JUMP_OVER = 3.5                          # studs the hips rise over standing
MOVE = {"왼팔": 110, "오른팔": 110, "왼손": 200, "오른손": 200, "왼다리": 80, "오른다리": 80, "몸통": 45, "고개": 70}
HINT = {
    "모양": "pose / amp (ChoreoFixes), 손목은 bend (§20)",
    "방향": "faceOffset / turn / spin",
    "늦음": "조각 at / blend / slowIn (박자)",
    "빠름": "조각 at / blend (박자)",
    "hit 빠짐": "still(짧게) / steady / ease 줄이기: 딱 멈추게",
    "게임만 hit": "blend 늘리기 / 떨림이면 guard_scan",
    "멈춤": "freeze / still 끝 당기기",
    "작음": "amp 키우기 / 원본 조각 다시",
    "과함": "amp 줄이기 / 다리는 원본 크기로(스텝 · plant 확인)",
    "손목 과함": "bend 줄이기(총 꺾임 90° 아래, 105°↑는 부러져 보임)",
    "점프 과함": "ChoreoJumps height 낮추기(3.2스터드 아래)",
    "바운스": "ChoreoBounce / 무릎 pose (박 위상)",
}


# ---------------------------------------------------------------- loading
def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def arrays(samples, video):
    """(T, P[N,19,3], seg, extra) from pose json samples; unseen points NaN."""
    T, P, seg, img, vt = [], [], [], [], []
    for s in samples:
        if not s.get("p"):
            continue
        row = np.full((len(NAMES), 3), np.nan)
        for n, v in s["p"].items():
            if n in NI and v is not None:
                row[NI[n]] = v
        if video:
            vis = s.get("vis") or {}
            for n, c in vis.items():
                if n in NI and c < 0.5:
                    row[NI[n]] = np.nan
            hs = s.get("hs") or {}
            for k, n in (("L", "lhand"), ("R", "rhand")):
                if hs.get(k) != "hand":
                    row[NI[n]] = np.nan
        T.append(s["t"])
        P.append(row)
        seg.append(s.get("cam", 0) if video else 0)
        img.append(s.get("img"))
        vt.append(s.get("vt"))
    return np.array(T), np.array(P), np.array(seg), img, vt


MIRROR_PERM = [NI[("r" + n[1:]) if n[0] == "l" and ("r" + n[1:]) in NI else (("l" + n[1:]) if n[0] == "r" and ("l" + n[1:]) in NI else n)]
               for n in NAMES]


def mirror(P):
    M = P[:, MIRROR_PERM, :].copy()
    M[..., 0] *= -1
    return M


def smooth_runs(T, P, seg, gap):
    """Median of 3 then 1-2-1 inside runs (same camera, no gap): the video landmarks shake a little."""
    out = P.copy()
    brk = np.where((np.diff(T) > gap) | (np.diff(seg) != 0))[0] + 1
    for a, b in zip(np.r_[0, brk], np.r_[brk, len(T)]):
        if b - a < 3:
            continue
        x = P[a:b]
        pad = np.concatenate([x[:1], x, x[-1:]])
        med = np.nanmedian(np.stack([pad[:-2], pad[1:-1], pad[2:]]), axis=0)
        pad = np.concatenate([med[:1], med, med[-1:]])
        st = np.stack([pad[:-2], pad[1:-1], pad[1:-1], pad[2:]])
        out[a:b] = np.nanmean(st, axis=0)
        out[a:b][np.isnan(x)] = np.nan
    return out


def resample(T, P, seg, grid, maxgap):
    i1 = np.clip(np.searchsorted(T, grid, side="left"), 0, len(T) - 1)
    i0 = np.clip(i1 - 1, 0, len(T) - 1)
    exact = np.abs(T[i1] - grid) < 1e-6
    i0 = np.where(exact, i1, i0)
    span = T[i1] - T[i0]
    w = np.where(span > 1e-9, (grid - T[i0]) / np.where(span > 1e-9, span, 1), 0.0)
    ok = (grid >= T[0] - 1e-6) & (grid <= T[-1] + 1e-6) & (span <= maxgap) & (seg[i0] == seg[i1])
    R = P[i0] * (1 - w)[:, None, None] + P[i1] * w[:, None, None]
    R[~ok] = np.nan
    return R


# ---------------------------------------------------------------- body frame
def body(P):
    """Points in the dancer's flat frame (left, up, forward), torso lengths, round the hip centre; + yaw."""
    lh, rh, ls, rs = P[:, NI["lhip"]], P[:, NI["rhip"]], P[:, NI["lsho"]], P[:, NI["rsho"]]
    hipc, shoc = (lh + rh) / 2, (ls + rs) / 2
    torso = np.linalg.norm(shoc - hipc, axis=1)
    X = (lh - rh) + (ls - rs)
    X[:, 1] = 0
    X /= np.linalg.norm(X, axis=1, keepdims=True) + 1e-12
    F = np.stack([-X[:, 2], np.zeros(len(X)), X[:, 0]], 1)  # cross(X, up)
    yaw = np.degrees(np.arctan2(F[:, 0], F[:, 2]))
    ear = (P[:, NI["lear"]] + P[:, NI["rear"]]) / 2
    Q = np.concatenate([P, hipc[:, None], shoc[:, None], ear[:, None]], 1) - hipc[:, None]
    B = np.stack([(Q * X[:, None]).sum(-1), Q[..., 1], (Q * F[:, None]).sum(-1)], -1) / torso[:, None, None]
    return B, yaw, torso


def seg_units(B):
    a = np.array([AI[s[1]] for s in SEGS])
    b = np.array([AI[s[2]] for s in SEGS])
    V = B[:, b] - B[:, a]
    n = np.linalg.norm(V, axis=-1, keepdims=True)
    U = V / np.where(n > 1e-9, n, np.nan)
    return U, n[..., 0]


def ang_between(A, Bv):
    return np.degrees(np.arccos(np.clip((A * Bv).sum(-1), -1, 1)))


def wrapd(a):
    return (a + 180) % 360 - 180


def movavg(x, k):
    """NaN-aware moving average over k samples (centred)."""
    k = max(1, int(k))
    m = ~np.isnan(x)
    xs = np.where(m, x, 0.0)
    ker = np.ones(k)
    s = np.convolve(xs, ker, "same")
    c = np.convolve(m.astype(float), ker, "same")
    return np.where(c > 0, s / np.maximum(c, 1e-9), np.nan)


def runs(flag, min_n, gap_n=0):
    """[(a, b)] index runs of True, gaps up to gap_n closed, at least min_n long."""
    out = []
    i, n = 0, len(flag)
    while i < n:
        if flag[i]:
            j = i
            while j < n and flag[j]:
                j += 1
            if out and i - out[-1][1] <= gap_n:
                out[-1] = (out[-1][0], j)
            else:
                out.append((i, j))
            i = j
        else:
            i += 1
    return [(a, b) for a, b in out if b - a >= min_n]


# ---------------------------------------------------------------- music beats
def beats(path, off, t0, t1):
    """Beat times in song seconds from the original video's sound (tempo + phase, then each beat nudged
    to the nearest onset within 40 ms)."""
    sr, hop, win = 11025, 128, 1024
    try:
        raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-vn", "-ac", "1", "-ar", str(sr), "-f", "s16le", "-"],
                             capture_output=True, timeout=300).stdout
    except Exception:
        return None
    x = np.frombuffer(raw, np.int16).astype(np.float32) / 32768
    if len(x) < sr * 5:
        return None
    frames = 1 + (len(x) - win) // hop
    hann = np.hanning(win).astype(np.float32)
    parts, prev = [], None
    for c0 in range(0, frames, 4096):  # in chunks: the whole song at once needs gigabytes
        c1 = min(frames, c0 + 4096)
        idx = np.arange(win)[None, :] + hop * np.arange(c0, c1)[:, None]
        sp = np.log1p(np.abs(np.fft.rfft(x[idx] * hann, axis=1))[:, : win // 4] * 20)
        if prev is not None:
            sp = np.vstack([prev, sp])
        parts.append(np.maximum(np.diff(sp, axis=0), 0).sum(axis=1))
        prev = sp[-1:]
    flux = np.concatenate(parts)
    flux = (flux - flux.mean()) / (flux.std() + 1e-9)
    fr = sr / hop
    best = None
    for bpm in np.arange(70, 181, 0.1):
        ac = 0
        for m in (1, 2, 4):
            lag = int(round(m * 60 / bpm * fr))
            ac += flux[lag:].dot(flux[:-lag]) / (len(flux) - lag)
        if best is None or ac > best[0]:
            best = (ac, bpm)
    bpm = best[1]
    # fold double tempo into the usual dance range
    while bpm > 150:
        bpm /= 2
    while bpm < 75:
        bpm *= 2
    period = 60 / bpm
    phases = np.linspace(0, period, 120, endpoint=False)
    grid = np.arange(0, len(flux) / fr - period, period)
    sc = [flux[np.clip(((grid + ph) * fr).round().astype(int), 0, len(flux) - 1)].sum() for ph in phases]
    ph = phases[int(np.argmax(sc))]
    out = []
    for b in grid + ph:
        i = int(round(b * fr))
        j0, j1 = max(0, i - int(0.04 * fr)), min(len(flux), i + int(0.04 * fr) + 1)
        k = j0 + int(np.argmax(flux[j0:j1])) if j1 > j0 else i
        bb = k / fr if flux[k] > 1.0 else b
        s = bb + off
        if t0 - period <= s <= t1 + period:
            out.append(round(s, 3))
    return {"bpm": round(bpm, 2), "period": period, "beats": out}


# ---------------------------------------------------------------- hits
def find_hits(speed, ts, peak_min, valid):
    """Moments a fast move stops: a speed peak (>= peak_min) followed within 0.3 s by a dip under 35 % of it.
    The hit time = the dip (refined with a parabola). Returns [(t, peak, sharpness)]."""
    out = []
    n = len(speed)
    s = np.nan_to_num(speed, nan=0.0)
    i = 1
    look = int(0.3 / DT)
    while i < n - 1:
        if s[i] >= peak_min and s[i] >= s[i - 1] and s[i] >= s[i + 1] and valid[i]:
            j_end = min(n - 1, i + look)
            seg = s[i:j_end + 1]
            j = i + int(np.argmin(seg))
            if s[j] <= 0.35 * s[i] and all(valid[i:j + 1]):
                # parabola through the dip
                tj = ts[j]
                if 0 < j < n - 1:
                    a, b, c = s[j - 1], s[j], s[j + 1]
                    den = a - 2 * b + c
                    if abs(den) > 1e-9:
                        tj = ts[j] + 0.5 * (a - c) / den * DT
                sharp = (s[i] - s[j]) / max(DT, ts[j] - ts[i])
                if out and tj - out[-1][0] < 0.12:
                    if s[i] > out[-1][1]:
                        out[-1] = (tj, s[i], sharp)
                else:
                    out.append((tj, s[i], sharp))
                i = j + 1
                continue
        i += 1
    return out


def near_beat(t, beat_arr):
    """Signed distance (s) to the nearest beat or half beat."""
    if beat_arr is None or len(beat_arr) < 2:
        return None
    k = np.searchsorted(beat_arr, t)
    cands = []
    for q in (k - 1, k):
        if 0 <= q < len(beat_arr):
            cands.append(beat_arr[q])
            if q + 1 < len(beat_arr):
                cands.append((beat_arr[q] + beat_arr[q + 1]) / 2)
    d = [t - c for c in cands]
    return min(d, key=abs)


# ---------------------------------------------------------------- words
def seg_words(u, side):
    if u is None or np.any(np.isnan(u)):
        return "-"
    return pc.vdir([u[0] * side, u[1], u[2]])


def joint_angle(B, i, a, b, c):
    v1, v2 = B[i, AI[a]] - B[i, AI[b]], B[i, AI[c]] - B[i, AI[b]]
    n = np.linalg.norm(v1) * np.linalg.norm(v2)
    if not n or np.isnan(n):
        return None
    return float(np.degrees(np.arccos(np.clip(v1.dot(v2) / n, -1, 1))))


def group_words(g, BV, BG, UV, UG, i):
    """What the group looks like in the video and in the game at index i."""
    def one(B, U):
        parts = []
        for si in GSEG[g]:
            name, a, b, _, side = SEGS[si]
            parts.append("%s %s" % (name.split()[-1], seg_words(U[i, si], side)))
        if g in ("왼팔", "오른팔"):
            p = "l" if g == "왼팔" else "r"
            e = joint_angle(B, i, p + "sho", p + "elb", p + "wri")
            if e is not None:
                parts.append("팔꿈치 %d°" % round(e))
        if g in ("왼다리", "오른다리"):
            p = "l" if g == "왼다리" else "r"
            e = joint_angle(B, i, p + "hip", p + "kne", p + "ank")
            if e is not None:
                parts.append("무릎 %d°" % round(e))
        if g == "몸통":
            u = U[i, GSEG[g][0]]
            if not np.any(np.isnan(u)):
                parts = ["앞으로 %d° 숙임" % round(math.degrees(math.atan2(u[2], u[1]))) if u[2] > 0.15 else
                         ("뒤로 %d° 젖힘" % round(math.degrees(math.atan2(-u[2], u[1]))) if u[2] < -0.15 else "바로"),
                         "옆 %+d°" % round(math.degrees(math.atan2(u[0], u[1])))]
                s2 = U[i, GSEG[g][1]]
                if not np.any(np.isnan(s2)):
                    parts.append("어깨 %s" % ("왼쪽 올라감" if s2[1] > 0.17 else ("오른쪽 올라감" if s2[1] < -0.17 else "수평")))
        if g == "고개":
            u = U[i, GSEG[g][1]]
            if not np.any(np.isnan(u)):
                yaw = math.degrees(math.atan2(u[0], u[2]))
                pit = math.degrees(math.atan2(u[1], math.hypot(u[0], u[2])))
                parts = ["%s %d°" % ("왼쪽 봄" if yaw > 0 else "오른쪽 봄", abs(round(yaw))) if abs(yaw) > 15 else "정면",
                         "%s %d°" % ("듦" if pit > 0 else "숙임", abs(round(pit))) if abs(pit) > 12 else ""]
                parts = [p for p in parts if p]
        return ", ".join(parts)
    return one(BV, UV), one(BG, UG)


def ft(t):
    m = int(t // 60)
    return "%d:%04.1f" % (m, t - 60 * m)


# ---------------------------------------------------------------- main analysis
def analyse(dv, dg, mirror_mode="auto", t_from=None, t_to=None, video_path=None):
    TV, PV, segV, imgV, vtV = arrays(dv["samples"], True)
    TG, PG, segG, _, _ = arrays(dg["samples"], False)
    off = float(dv.get("off", 0.0))
    PV = smooth_runs(TV, PV, segV, 0.11)
    t0 = max(TV[0], TG[0], t_from if t_from is not None else -1e9)
    t1 = min(TV[-1], TG[-1], t_to if t_to is not None else 1e9)
    ts = np.round(np.arange(t0, t1, DT), 3)
    RV0 = resample(TV, PV, segV, ts, 0.11)
    RG = resample(TG, PG, segG, ts, 0.16)

    BG, yawG, _ = body(RG)
    UG, _ = seg_units(BG)

    def armscore(RV):
        B, _, _ = body(RV)
        U, _ = seg_units(B)
        c = (U[:, :4] * UG[:, :4]).sum(-1)
        return float(np.nanmean(c))

    s_plain = armscore(RV0)
    s_mir = armscore(mirror(RV0))
    use_m = mirror_mode == "on" or (mirror_mode == "auto" and s_mir > s_plain + 0.05)
    RV = mirror(RV0) if use_m else RV0
    BV, yawV, _ = body(RV)
    UV, _ = seg_units(BV)
    # one 1-2-1 pass on the game too, so both sides are read alike
    def soft(X):
        Y = X.copy()
        Y[1:-1] = (X[:-2] + 2 * X[1:-1] + X[2:]) / 4
        bad = np.isnan(Y)
        Y[bad] = X[bad]
        return Y
    UGs = soft(UG)
    UVs = soft(UV)

    # camera cuts: leave out 0.25 s round each
    cut_t = [TV[i] for i in range(1, len(TV)) if segV[i] != segV[i - 1]]
    valid = ~np.isnan(BV[:, AI["SHO"], 0])
    for c in cut_t:
        valid[np.abs(ts - c) < 0.25] = False
    seen = float(valid.mean())

    E = ang_between(UVs, UGs)          # (N, S)
    E[~valid] = np.nan
    GE = {}
    for g in GROUPS:
        e = np.nanmean(E[:, GSEG[g]], axis=1) if len(GSEG[g]) > 1 else E[:, GSEG[g][0]]
        GE[g] = movavg(e, 5)

    # speeds (deg/s) per group
    def speeds(U):
        d = np.full(U.shape[:2], np.nan)
        d[1:-1] = np.degrees(np.arccos(np.clip((U[2:] * U[:-2]).sum(-1), -1, 1))) / (2 * DT)
        return d
    SV, SG = speeds(UVs), speeds(UGs)
    GSV = {g: np.nansum(SV[:, GSEG[g]], axis=1) * np.where(np.all(np.isnan(SV[:, GSEG[g]]), 1), np.nan, 1) for g in GROUPS}
    GSG = {g: np.nansum(SG[:, GSEG[g]], axis=1) * np.where(np.all(np.isnan(SG[:, GSEG[g]]), 1), np.nan, 1) for g in GROUPS}
    # holes in the game recording (a dropped log stretch): unknown, never "the game stopped" (D-1893, Boogie 0:17.05 +0.7 s)
    gvalid = ~np.isnan(BG[:, AI["SHO"], 0])
    game_gaps = [(round(float(ts[a]), 2), round(float(ts[min(b, len(ts) - 1)]), 2)) for a, b in runs(~gvalid, int(0.1 / DT))]

    issues = []

    def add(kind, g, a, b, sev, text):
        issues.append({"t0": round(float(ts[a]), 2), "t1": round(float(ts[min(b, len(ts) - 1)]), 2), "kind": kind, "part": g,
                       "sev": round(float(sev), 2), "text": text, "hint": HINT.get(kind, "")})

    # ---- 1. shape
    for g in GROUPS:
        e = GE[g]
        flag = np.nan_to_num(e, nan=0) > THR[g]
        for a, b in runs(flag, int(0.3 / DT), int(0.12 / DT)):
            seg = e[a:b]
            k = a + int(np.nanargmax(seg))
            sev = float(np.nansum(seg - THR[g]) * DT) / THR[g] * 3
            wv, wg = group_words(g, BV, BG, UV, UG, k)
            add("모양", g, a, b, sev, "%s 최대 %d° 차이 (%s) 원본: %s / 게임: %s" % (g, round(float(np.nanmax(seg))), ft(ts[k]), wv, wg))

    # ---- 5. facing
    dyaw = wrapd(yawV - yawG)
    cam = float(np.nanmedian(dyaw[valid])) if valid.any() else 0.0
    dy = wrapd(dyaw - cam)
    dy[~valid] = np.nan
    dys = movavg(dy, 7)
    for a, b in runs(np.abs(np.nan_to_num(dys)) > 50, int(0.4 / DT), int(0.12 / DT)):
        k = a + int(np.nanargmax(np.abs(dys[a:b])))
        sev = float(np.nansum(np.abs(dys[a:b]) - 50) * DT) / 50 * 3
        def fw(y):
            y = wrapd(y)
            return "정면" if abs(y) < 35 else ("뒤" if abs(y) > 135 else ("몸 오른쪽이 앞" if y > 0 else "몸 왼쪽이 앞"))
        add("방향", "몸 방향", a, b, sev, "몸 방향 %d° 차이 (%s) 원본: %s / 게임: %s" %
            (round(abs(dys[k])), ft(ts[k]), fw(yawV[k] - cam), fw(yawG[k])))

    # ---- 2. lag per group (velocity correlation, 2 s windows every 0.5 s)
    VV = np.zeros_like(UVs)
    VG = np.zeros_like(UGs)
    VV[1:-1] = (UVs[2:] - UVs[:-2]) / (2 * DT)
    VG[1:-1] = (UGs[2:] - UGs[:-2]) / (2 * DT)
    VV = np.nan_to_num(VV)
    VG = np.nan_to_num(VG)
    VV[~valid] = 0
    VV[~gvalid] = 0
    VG[~gvalid] = 0
    win, hopn, maxlag = int(2.0 / DT), int(0.5 / DT), int(0.4 / DT)
    lags = {}
    for g in GROUPS:
        idx = GSEG[g]
        a = VV[:, idx].reshape(len(ts), -1)
        n = len(ts)
        cs_aa = np.r_[0, np.cumsum((a * a).sum(1))]
        cc = {}
        for L in range(-maxlag, maxlag + 1):
            b = np.zeros_like(a)
            if L >= 0:
                b[: n - L] = VG[L:, idx].reshape(n - L, -1)
            else:
                b[-L:] = VG[: n + L, idx].reshape(n + L, -1)
            b[~valid] = 0
            cc[L] = (np.r_[0, np.cumsum((a * b).sum(1))], np.r_[0, np.cumsum((b * b).sum(1))])
        rows = []
        for s0 in range(0, n - win, hopn):
            s1 = s0 + win
            if (valid[s0:s1] & gvalid[s0:s1]).mean() < 0.7:
                continue
            mv = np.nanmean(GSV[g][s0:s1])
            if not (mv >= MOVE[g] * 1.3):
                continue
            aa = cs_aa[s1] - cs_aa[s0]
            vals = []
            for L in range(-maxlag, maxlag + 1):
                ab = cc[L][0][s1] - cc[L][0][s0]
                bb = cc[L][1][s1] - cc[L][1][s0]
                vals.append(ab / math.sqrt(aa * bb) if aa > 0 and bb > 0 else -1)
            vals = np.array(vals)
            k = int(np.argmax(vals))
            if vals[k] < 0.45:
                continue
            lag = (k - maxlag) * DT
            if 0 < k < len(vals) - 1:
                den = vals[k - 1] - 2 * vals[k] + vals[k + 1]
                if abs(den) > 1e-9:
                    lag += 0.5 * (vals[k - 1] - vals[k + 1]) / den * DT
            rows.append((float(ts[s0] + 1.0), round(lag, 3), round(float(vals[k]), 2), round(float(vals[maxlag]), 2)))
        lags[g] = rows
    # stretches where most moving parts are late / early
    lag_t = {}
    for g in ("왼팔", "오른팔", "왼다리", "오른다리", "몸통"):
        for t, l, c, c0 in lags[g]:
            lag_t.setdefault(round(t, 2), []).append(l)
    lt = sorted(lag_t)
    lv = np.array([np.median(lag_t[t]) for t in lt]) if lt else np.array([])
    lag_overall = float(np.median(lv)) if len(lv) else None
    if len(lv):
        # a steady offset over the whole song is the recording / --off, not the dance: judge each place against it
        lv = lv - lag_overall
        for sign, kind in ((1, "늦음"), (-1, "빠름")):
            flag = (lv * sign) >= 0.07
            for a, b in runs(list(flag), 2, 1):
                seg = lv[a:b]
                k = a + int(np.argmax(seg * sign))
                ia = int(np.searchsorted(ts, lt[a] - 1.0))
                ib = int(np.searchsorted(ts, lt[b - 1] + 1.0))
                parts = [g for g in GROUPS if any(abs(t - lt[k]) < 0.01 and (l - lag_overall) * sign >= 0.07 for t, l, _, _ in lags[g])]
                add(kind, ",".join(parts) or "몸", ia, ib, abs(float(np.median(seg))) / 0.07 * (b - a) * 0.6,
                    "게임이 원본보다 %.2f초 %s (곡 전체 차이를 빼고, 가장 큰 곳 %s, %s)" % (abs(float(np.median(seg))), "늦게 움직임" if sign > 0 else "먼저 움직임",
                                                         ft(lt[k]), " · ".join(parts) or "여러 부위"))

    # ---- 3. hits
    beat_info = beats(video_path, off, float(ts[0]), float(ts[-1])) if video_path and os.path.exists(video_path) else None
    BEATS = np.array(beat_info["beats"]) if beat_info else None
    hits = []   # for the viewer
    hit_stats = {"matched": [], "missing": 0, "extra": 0, "video": 0}
    for g in GROUPS:
        sv = movavg(GSV[g], 3)
        sg = movavg(GSG[g], 3)
        # a video hit counts only where every point of the part was read for 0.2 s round it (a lost or
        # swapped landmark makes a fake fast move) and the speed is a body's (a left/right swap reads 2000°/s+)
        gv = valid & ~np.isnan(UV[:, GSEG[g]]).any(axis=(1, 2)) & (np.nan_to_num(sv) < 1800 * len(GSEG[g]))
        gv = np.convolve(~gv, np.ones(int(0.2 / DT) * 2 + 1), "same") == 0
        hv = find_hits(sv, ts, HIT_PEAK[g], gv)
        hg = find_hits(sg, ts, HIT_PEAK[g] * 0.8, gvalid)
        tg = np.array([h[0] for h in hg])
        used = set()
        hit_stats["video"] += len(hv)
        for t, pk, sh in hv:
            j = None
            if len(tg):
                k = int(np.argmin(np.abs(tg - t)))
                if abs(tg[k] - t) <= 0.25 and k not in used:
                    j = k
            bv = near_beat(t, BEATS)
            if j is not None:
                used.add(j)
                d = float(tg[j] - t)
                bg = near_beat(float(tg[j]), BEATS)
                hits.append({"g": g, "tv": round(t, 3), "tg": round(float(tg[j]), 3), "d": round(d, 3),
                             "bv": None if bv is None else round(bv, 3), "bg": None if bg is None else round(bg, 3)})
                hit_stats["matched"].append(d)
            else:
                # the game has no stop here: is it moving smoothly through, or not moving at all?
                i = int(np.searchsorted(ts, t))
                if not gvalid[max(0, i - int(0.25 / DT)):i + int(0.25 / DT)].all():
                    continue
                lo, hi = max(0, i - int(0.25 / DT)), min(len(ts), i + int(0.25 / DT))
                gpk = float(np.nanmax(sg[lo:hi])) if hi > lo else 0
                hits.append({"g": g, "tv": round(t, 3), "tg": None, "d": None, "bv": None if bv is None else round(bv, 3),
                             "bg": None, "why": "흐름" if gpk >= HIT_PEAK[g] * 0.6 else "작음"})
                if pk >= HIT_PEAK[g] * 1.4:
                    hit_stats["missing"] += 1
        for k, (t, pk, sh) in enumerate(hg):
            if k in used:
                continue
            i = int(np.searchsorted(ts, t))
            if i >= len(ts) or not valid[i]:
                continue
            lo, hi = max(0, i - int(0.3 / DT)), min(len(ts), i + int(0.3 / DT))
            vpk = float(np.nanmax(sv[lo:hi])) if hi > lo else 0
            if pk >= HIT_PEAK[g] * 1.4 and vpk < HIT_PEAK[g] * 0.6:
                hits.append({"g": g, "tv": None, "tg": round(t, 3), "d": None, "bv": None,
                             "bg": None if BEATS is None else round(near_beat(t, BEATS), 3), "why": "게임만"})
                hit_stats["extra"] += 1
    hits.sort(key=lambda h: h["tv"] if h["tv"] is not None else h["tg"])
    # hit issues: strong video hits the game misses, 2+ in 1.5 s in the same group
    for g in GROUPS:
        miss = [h for h in hits if h["g"] == g and h["tg"] is None and h["tv"] is not None]
        groups_ = []
        for h in miss:
            if groups_ and h["tv"] - groups_[-1][-1]["tv"] < 1.5:
                groups_[-1].append(h)
            else:
                groups_.append([h])
        for grp in groups_:
            if len(grp) < 2:
                continue
            a = int(np.searchsorted(ts, grp[0]["tv"] - 0.2))
            b = int(np.searchsorted(ts, grp[-1]["tv"] + 0.2))
            why = "그냥 흘러가며 지나감" if sum(h["why"] == "흐름" for h in grp) * 2 >= len(grp) else "거의 안 움직임"
            add("hit 빠짐", g, a, b, len(grp) * 0.8, "원본은 %s을(를) %d번 딱 끊는데(%s) 게임은 %s" %
                (g, len(grp), ", ".join(ft(h["tv"]) for h in grp[:6]), why))
        extra = [h for h in hits if h["g"] == g and h.get("why") == "게임만"]
        for h in extra:
            a = int(np.searchsorted(ts, h["tg"] - 0.25))
            b = int(np.searchsorted(ts, h["tg"] + 0.25))
            add("게임만 hit", g, a, b, 0.6, "%s: 원본은 부드럽게 가는데 게임만 %s에 툭 끊김/튐" % (g, ft(h["tg"])))
    # off-beat hits: the game hit is 70 ms+ further from the beat than the video's, 3+ within 3 s, all the same
    # way (late or early, after the song-wide lag is taken off): mixed signs are hit-matching noise (D-1892, TWS)
    base = lag_overall or 0.0
    if BEATS is not None:
        for sign in (1, -1):
            bad = [h for h in hits if h["tg"] is not None and h["tv"] is not None and h["bv"] is not None and h["bg"] is not None
                   and abs(h["bg"]) - abs(h["bv"]) >= 0.07 and (h["d"] - base) * sign >= 0.06]
            cl = []
            for h in bad:
                if cl and h["tv"] - cl[-1][-1]["tv"] < 3:
                    cl[-1].append(h)
                else:
                    cl.append([h])
            for grp in cl:
                if len(grp) < 3:
                    continue
                md = float(np.median([h["d"] for h in grp]))
                a = int(np.searchsorted(ts, grp[0]["tv"] - 0.2))
                b = int(np.searchsorted(ts, grp[-1]["tv"] + 0.2))
                add("늦음" if sign > 0 else "빠름", ",".join(sorted({h["g"] for h in grp})), a, b, len(grp) * 0.7,
                    "박에 딱 떨어지는 동작 %d개가 게임에서 박을 벗어남: 평균 %+d ms (%s)" %
                    (len(grp), round(md * 1000), ", ".join("%s %+dms" % (ft(h["tv"]), round(h["d"] * 1000)) for h in grp[:5])))

    # ---- 4. amount of movement, bounce, nod, shoulder
    w = int(1.0 / DT)
    amount = {}
    for g in GROUPS:
        mv = movavg(GSV[g], w)
        mg = movavg(GSG[g], w)
        mvv = mv.copy()
        mvv[~valid] = np.nan
        ratio = mg / np.where(mvv > 1e-6, mvv, np.nan)
        amount[g] = ratio
        big = np.nan_to_num(mvv) >= MOVE[g]
        for a, b in runs(big & (np.nan_to_num(ratio, nan=1) < 0.2), int(0.5 / DT), int(0.15 / DT)):
            add("멈춤", g, a, b, (b - a) * DT * 2, "%s: 원본은 움직이는데 게임은 거의 멈춤 (원본의 %d%%)" %
                (g, round(100 * float(np.nanmean(ratio[a:b])))))
        small, over_r = SIZE.get(g, (0.45, 2.2))
        for a, b in runs(big & (np.nan_to_num(ratio, nan=1) >= 0.2) & (np.nan_to_num(ratio, nan=1) < 0.45), int(0.75 / DT), int(0.15 / DT)):
            add("작음", g, a, b, (b - a) * DT, "%s 움직임이 원본의 %d%%밖에 안 됨 (작고 밋밋함)" % (g, round(100 * float(np.nanmean(ratio[a:b])))))
        if small > 0.45:
            # bigger-than-the-video rule: as big as the video (or a bit under) is still small, held 1.5 s+
            for a, b in runs(big & (np.nan_to_num(ratio, nan=2) >= 0.45) & (np.nan_to_num(ratio, nan=2) < small), int(1.5 / DT), int(0.2 / DT)):
                add("작음", g, a, b, (b - a) * DT * 0.3, "%s 움직임이 원본의 %d%% — 게임은 원본보다 커야 함(1.0-1.6배)" % (g, round(100 * float(np.nanmean(ratio[a:b])))))
        over = (np.nan_to_num(mg) >= MOVE[g]) & (np.nan_to_num(ratio, nan=1) > over_r) & valid
        for a, b in runs(over, int(1.0 / DT), int(0.15 / DT)):
            add("과함", g, a, b, (b - a) * DT * 0.8, "%s 움직임이 원본의 %.1f배 (기준 %.1f배 넘음)" % (g, float(np.nanmean(ratio[a:b])), over_r))
        if g in ("왼다리", "오른다리"):
            # the video's legs stand still but the game's move (steps the video has not)
            still_v = (np.nan_to_num(mvv, nan=1e9) < MOVE[g] * 0.4) & valid
            for a, b in runs(still_v & (np.nan_to_num(mg) >= MOVE[g]), int(0.5 / DT), int(0.15 / DT)):
                add("과함", g, a, b, (b - a) * DT, "%s: 원본 다리는 가만히 있는데 게임만 움직임(원본에 없는 스텝 · 다리 꼬기)" % g)

    # wrists bent past the band, and jumps too high (game only, exact)
    try:
        fl = {"L": np.full(len(ts), np.nan), "R": np.full(len(ts), np.nan)}
        near = np.zeros(len(ts), bool)
        GS = [x for x in dg["samples"] if x.get("p")]
        GT = np.array([x["t"] for x in GS])
        for x in GS:
            f = pc.features(x)
            if not f:
                continue
            i = int(round((x["t"] - ts[0]) / DT))
            if 0 <= i < len(ts):
                for k in "LR":
                    if f.get(k + "flex") is not None:
                        fl[k][max(0, i - 1):i + 2] = abs(f[k + "flex"])
                P = x["p"]
                # a hand touching the other hand or the body (palms together, hand on shoulder / face / chest, user-asked
                # poses like TWS 0:07-0:09, 1:29) bends the wrist on purpose: let those off
                tor = f["torso"]
                def close(a, b, r):
                    return a in P and b in P and pc.norm(pc.sub(P[a], P[b])) / tor < r
                touch = close("lwri", "rwri", 0.45) or close("lhand", "rhand", 0.35)
                for hnd in ("lhand", "rhand"):
                    for bp in ("nose", "lear", "rear", "lsho", "rsho"):
                        touch = touch or close(hnd, bp, 0.35)
                    if hnd in P and "lsho" in P and "lhip" in P:
                        chest = pc.mid(pc.mid(P["lsho"], P["rsho"]), pc.mid(pc.mid(P["lsho"], P["rsho"]), pc.mid(P["lhip"], P["rhip"])))
                        touch = touch or pc.norm(pc.sub(P[hnd], chest)) / tor < 0.35
                near[max(0, i - 1):i + 2] = touch
        for k, side in (("L", "왼"), ("R", "오른")):
            v = fl[k]
            for lim, txt in ((WRIST_BROKEN, "부러져 보이는 각도"), (WRIST_OVER, "기준 90° 넘음")):
                mask = (np.nan_to_num(v) > lim) & ~near
                if lim == WRIST_OVER:
                    mask &= ~(np.nan_to_num(v) > WRIST_BROKEN)
                for a, b in runs(mask, int(0.15 / DT), int(0.1 / DT)):
                    add("손목 과함", side + "손", a, b, (b - a) * DT * 4, "%s손목 %d° 꺾임 (%s)" % (side, round(float(np.nanmax(v[a:b]))), txt))
        torso_st = float(np.median([pc.norm(pc.sub(pc.mid(x["p"]["lsho"], x["p"]["rsho"]), pc.mid(x["p"]["lhip"], x["p"]["rhip"])))
                                    for x in GS[:: max(1, len(GS) // 200)] if all(k in x["p"] for k in ("lsho", "rsho", "lhip", "rhip"))]))
        hh = np.array([x.get("h", {}).get("hip", np.nan) for x in GS], float)
        if np.isfinite(hh).any():
            base = np.nanmedian(hh)
            rise = (hh - base) * torso_st
            i = 0
            while i < len(GS):
                if rise[i] > JUMP_OVER:
                    j = i
                    while j < len(GS) and rise[j] > 1.0:
                        j += 1
                    a, b = int(np.searchsorted(ts, GT[i])), int(np.searchsorted(ts, GT[min(j, len(GS) - 1)]))
                    add("점프 과함", "점프", a, max(b, a + 1), 1.5, "점프 %.1f스터드 (기준 %.1f 넘음)" % (float(np.nanmax(rise[i:j])), JUMP_OVER))
                    i = j
                i += 1
    except Exception as e:  # never stop the review for these extras
        print("손목/점프 크기 검사 건너뜀:", e)

    # rhythmic little moves: (name, signal function)
    def hip_h(B):
        return -np.fmin(B[:, AI["lank"], 1], B[:, AI["rank"], 1])

    def nod(U):
        u = U[:, GSEG["고개"][1]]
        return np.degrees(np.arctan2(u[:, 1], np.hypot(u[:, 0], u[:, 2])))

    def shrug(U):
        return U[:, GSEG["몸통"][1], 1]

    grooves = {}
    for name, fv, fg, amp_min, unit_ in (("무릎 바운스", hip_h(BV), hip_h(BG), 0.035, "몸통"),
                                         ("고개 끄덕임", nod(UV), nod(UG), 4.0, "°"),
                                         ("어깨 들썩", shrug(UV), shrug(UG), 0.05, "")):
        dv_ = fv - movavg(fv, int(0.8 / DT))
        dg_ = fg - movavg(fg, int(0.8 / DT))
        dv_[~valid] = np.nan
        wv = int(1.5 / DT)
        av = np.sqrt(movavg(dv_ ** 2, wv))
        ag = np.sqrt(movavg(dg_ ** 2, wv))
        cr = movavg(dv_ * dg_, wv) / (av * ag + 1e-9)
        grooves[name] = {"v": dv_, "g": dg_}
        has = np.nan_to_num(av) >= amp_min

        def beat_like(a, b):
            """The video's up-down repeats with the beat (one or two beats a cycle): else it is landmark shake (D-1892)."""
            if not beat_info:
                return True
            lo, hi = max(0, a - int(0.75 / DT)), min(len(ts), b + int(0.75 / DT))
            x = np.nan_to_num(dv_[lo:hi])
            x = x - x.mean()
            n = float(np.dot(x, x))
            best = -1
            for m in (1, 2):
                L = int(round(m * beat_info["period"] / DT))
                if n > 0 and L < len(x) - 10:
                    best = max(best, float(np.dot(x[:-L], x[L:])) / n)
            return best >= 0.3

        for a, b in runs(has & (np.nan_to_num(ag) < 0.45 * np.nan_to_num(av)), int(1.0 / DT), int(0.2 / DT)):
            if not beat_like(a, b):
                continue
            add("바운스", name, a, b, (b - a) * DT, "%s: 원본은 박마다 하는데 게임은 %s (원본 크기의 %d%%)" %
                (name, "거의 없음" if np.nanmean(ag[a:b]) < 0.2 * np.nanmean(av[a:b]) else "작음",
                 round(100 * float(np.nanmean(ag[a:b]) / np.nanmean(av[a:b])))))
        both = has & (np.nan_to_num(ag) >= 0.45 * np.nan_to_num(av))
        for a, b in runs(both & (np.nan_to_num(cr) < -0.35), int(1.0 / DT), int(0.2 / DT)):
            if not beat_like(a, b):
                continue
            add("바운스", name, a, b, (b - a) * DT * 1.2, "%s 박이 반대: 원본이 내려갈 때 게임은 올라감 (상관 %.2f)" %
                (name, float(np.nanmean(cr[a:b]))))

    # ---- summary numbers
    summary = {"mirror": use_m, "arm_plain": round(s_plain, 2), "arm_mirror": round(s_mir, 2), "seen": round(seen, 3),
               "t0": float(ts[0]), "t1": float(ts[-1]), "cam_yaw": round(cam, 1), "lag_overall": lag_overall, "game_gaps": game_gaps,
               "groups": {}, "hits": {}}
    for g in GROUPS:
        e = GE[g][valid]
        e = e[~np.isnan(e)]
        lg = [l for _, l, _, _ in lags[g]]
        summary["groups"][g] = {"mean": round(float(e.mean()), 1) if len(e) else None,
                                "ok": round(float((e <= THR[g]).mean()), 3) if len(e) else None,
                                "lag": round(float(np.median(lg)), 3) if lg else None, "lag_n": len(lg)}
    summary["size"] = {g: round(float(np.nanmedian(amount[g][np.isfinite(amount[g])])), 2) if np.isfinite(amount[g]).any() else None
                       for g in GROUPS if g in SIZE}
    md = hit_stats["matched"]
    summary["hits"] = {"video": hit_stats["video"], "matched": len(md), "missing": hit_stats["missing"], "extra": hit_stats["extra"],
                       "median_ms": round(float(np.median(md)) * 1000) if md else None,
                       "within60": round(float(np.mean(np.abs(md) <= 0.06)), 3) if md else None,
                       "within100": round(float(np.mean(np.abs(md) <= 0.1)), 3) if md else None}
    if BEATS is not None:
        bvs = [abs(h["bv"]) for h in hits if h["bv"] is not None and h["tv"] is not None]
        bgs = [abs(h["bg"]) for h in hits if h["bg"] is not None and h["tg"] is not None]
        summary["beat"] = {"bpm": beat_info["bpm"], "video_on": round(float(np.mean(np.array(bvs) <= 0.06)), 3) if bvs else None,
                           "game_on": round(float(np.mean(np.array(bgs) <= 0.06)), 3) if bgs else None}

    # merge near-duplicates of the same kind / part
    issues.sort(key=lambda x: (x["kind"], x["part"], x["t0"]))
    merged = []
    for it in issues:
        if merged and merged[-1]["kind"] == it["kind"] and merged[-1]["part"] == it["part"] and it["t0"] - merged[-1]["t1"] < 0.3:
            m = merged[-1]
            m["t1"] = max(m["t1"], it["t1"])
            if it["sev"] > m["sev"]:
                m["text"] = it["text"]
            m["sev"] = round(m["sev"] + it["sev"], 2)
        else:
            merged.append(dict(it))
    merged.sort(key=lambda x: x["t0"])
    for i, it in enumerate(merged):
        it["id"] = i + 1

    trv = None
    TRg = [(x["t"], x.get("tr")) for x in dg["samples"] if x.get("p") and x.get("tr")]
    if len(TRg) > 10:
        tt = np.array([q[0] for q in TRg])
        rr = np.array([q[1] for q in TRg], float)
        r2_ = np.stack([np.interp(ts, tt, rr[:, 0]), np.interp(ts, tt, rr[:, 1])], 1)
        k = int(0.3 / DT)
        trv = np.zeros(len(ts))
        trv[k:-k] = np.linalg.norm(r2_[2 * k:] - r2_[:-2 * k], axis=1) / (2 * k * DT)
    ctx = dict(trv=trv, GSG=GSG, ts=ts, valid=valid, BV=BV, BG=BG, yawV=yawV, yawG=yawG, cam=cam, GE=GE, lags=lags, hits=hits,
               beats=beat_info, amount=amount, grooves=grooves, use_m=use_m, off=off, TV=TV, imgV=imgV, vtV=vtV, dys=dys)
    return merged, summary, ctx


def edit_spans(ctx, bctx):
    """Where the edit changed the game, and for each the error against the video before -> after.
    Changed = the two recordings differ: bones 12°+ (mean of all; untouched parts of two recordings differ about 3°,
    TWS 2026-11-19), or facing 25°+, or the body's travel 0.25 torso/s+ (slides), or the hips 0.12 torso up / down,
    or the amount of motion (a twitch taken out) — for 0.2 s+ (D-1893)."""
    ts = ctx["ts"]
    UA, _ = seg_units(ctx["BG"])
    UB, _ = seg_units(bctx["BG"])
    d = movavg(np.nanmean(ang_between(UA, UB), axis=1), 7)
    dyaw = movavg(np.abs(wrapd(ctx["yawG"] - bctx["yawG"])), 7)
    hh = lambda B: -np.fmin(B[:, AI["lank"], 1], B[:, AI["rank"], 1])
    dh = movavg(np.abs(hh(ctx["BG"]) - hh(bctx["BG"])), 7)
    tv = lambda c_: c_.get("trv")
    dtr = movavg(np.abs(tv(ctx) - tv(bctx)), 7) if tv(ctx) is not None and tv(bctx) is not None else np.zeros(len(ts))
    sa = sum(np.nan_to_num(movavg(ctx["GSG"][g], 15)) for g in GROUPS)
    sb = sum(np.nan_to_num(movavg(bctx["GSG"][g], 15)) for g in GROUPS)
    dm = np.abs(sa - sb) / (np.maximum(sa, sb) + 150)
    why = [(np.nan_to_num(d) > 12, "자세"), (np.nan_to_num(dyaw) > 25, "방향"), (np.nan_to_num(dtr) > 0.25, "이동"),
           (np.nan_to_num(dh) > 0.12, "높이"), (np.nan_to_num(dm) > 0.45, "움직임 양")]
    flag = np.zeros(len(ts), bool)
    for f, _ in why:
        flag |= f
    spans = []
    for a, b in runs(flag, int(0.2 / DT), int(0.3 / DT)):
        trig = [w for f, w in why if f[a:b].any()]
        if trig == ["움직임 양"] and abs(np.mean(sa[a:b]) - np.mean(sb[a:b])) < 0.25 * max(np.mean(sa[a:b]), np.mean(sb[a:b]), 1):
            continue  # a moment's flicker, not a changed move
        ea = np.nanmean([np.nanmean(ctx["GE"][g][a:b]) for g in GROUPS])
        eb = np.nanmean([np.nanmean(bctx["GE"][g][a:b]) for g in GROUPS])
        spans.append({"t0": round(float(ts[a]), 2), "t1": round(float(ts[min(b, len(ts) - 1)]), 2),
                      "change": round(float(np.nanmax(d[a:b])), 1) if np.isfinite(d[a:b]).any() else 0.0, "what": [w for f, w in why if f[a:b].any()],
                      "move": [round(float(np.mean(sb[a:b])), 0), round(float(np.mean(sa[a:b])), 0)],
                      "trv": [round(float(np.nanmax(tv(bctx)[a:b])), 2), round(float(np.nanmax(tv(ctx)[a:b])), 2)] if tv(ctx) is not None else None,
                      "before": None if np.isnan(eb) else round(float(eb), 1), "after": None if np.isnan(ea) else round(float(ea), 1)})
    return spans


def tag_before(issues, before, spans, gaps=()):
    """Each issue: new = not there before (same kind and part, overlapping) AND inside a place the edit changed;
    elsewhere a 'new' issue is only the threshold flickering between two recordings. Before-issues no longer
    found inside an edited place: gone (fixed)."""
    def same(x, y):
        px, py = set(x["part"].split(",")), set(y["part"].split(","))
        return x["kind"] == y["kind"] and px & py and x["t0"] < y["t1"] + 0.2 and y["t0"] < x["t1"] + 0.2

    def edited(x):
        return any(x["t0"] < sp["t1"] + 0.3 and sp["t0"] - 0.3 < x["t1"] for sp in spans)
    for x in issues:
        x["new"] = (not any(same(x, y) for y in before)) and edited(x)
    for y in before:
        hole = any(y["t0"] < b + 0.3 and a - 0.3 < y["t1"] for a, b in gaps)  # unseen in the new recording: not "fixed"
        y["gone"] = (not any(same(x, y) for x in issues)) and edited(y) and not hole


# ---------------------------------------------------------------- outputs
def write_report(path, title, issues, summary, top):
    L = []
    s = summary
    L.append("안무 2차 검토 — %s" % title)
    L.append("구간 %s-%s, 원본 인식 %d%%, 좌우 %s (팔 일치도 그대로 %.2f / 거울 %.2f), 카메라 각도 보정 %+d°" %
             (ft(s["t0"]), ft(s["t1"]), round(100 * s["seen"]), "거울로 비교" if s["mirror"] else "그대로 비교",
              s["arm_plain"], s["arm_mirror"], round(s["cam_yaw"])))
    L.append("시간 = 곡 초(재생바). + = 게임이 늦음.")
    if s.get("game_gaps"):
        L.append("⚠ 게임 녹화가 빈 곳 %d: %s — 이 구간은 판정 못 함, 다시 녹화 필요" % (
            len(s["game_gaps"]), ", ".join("%s-%s" % (ft(a), ft(b)) for a, b in s["game_gaps"][:8])))
    L.append("")
    L.append("## 한눈에")
    h = s["hits"]
    if s.get("lag_overall") is not None:
        L.append("전체 박자: 게임이 원본보다 %+d ms (부위별 속도 상관의 중앙값)%s" % (round(s["lag_overall"] * 1000),
                 "  ← 곡 전체가 이만큼 밀림: pose_video --off 또는 녹화 지연부터 확인" if abs(s["lag_overall"]) >= 0.05 else ""))
    if h["matched"]:
        L.append("끊는 박(hit): 원본 %d개 중 %d개 짝, 중앙값 %+d ms, ±60ms 안 %d%%, ±100ms 안 %d%% / 크게 빠진 것 %d, 게임에만 %d" %
                 (h["video"], h["matched"], h["median_ms"], round(100 * h["within60"]), round(100 * h["within100"]), h["missing"], h["extra"]))
    if s.get("beat"):
        b = s["beat"]
        L.append("음악 박 %.1f BPM: 박(반박 포함) ±60ms에 떨어지는 hit 원본 %s / 게임 %s" %
                 (b["bpm"], "-" if b["video_on"] is None else "%d%%" % round(100 * b["video_on"]),
                  "-" if b["game_on"] is None else "%d%%" % round(100 * b["game_on"])))
    if s.get("size"):
        def band(g, v):
            lo, hi = SIZE[g]
            return "작음" if v < lo else ("과함" if v > hi else "좋음")
        L.append("크기(게임/원본 움직임 중앙값, 기준: 팔·몸통·고개 1.0-1.8배, 다리 0.45-1.5배): " + ", ".join(
            "%s %.2f %s" % (g, v, band(g, v)) for g, v in s["size"].items() if v is not None))
    L.append("")
    L.append("부위        평균오차  기준안   박자(중앙값)")
    for g, v in s["groups"].items():
        L.append("%-6s   %6s°   %5s   %s" % (g, "-" if v["mean"] is None else "%.0f" % v["mean"],
                                          "-" if v["ok"] is None else "%d%%" % round(100 * v["ok"]),
                                          "-" if v["lag"] is None else "%+d ms (%d창)" % (round(v["lag"] * 1000), v["lag_n"])))
    if s.get("before"):
        b = s["before"]["summary"]
        L.append("")
        L.append("## 편집 전 → 후")
        def pct(v):
            return "-" if v is None else "%d%%" % round(100 * v)
        for g, v in s["groups"].items():
            w = b["groups"].get(g, {})
            L.append("%-6s 기준 안 %s → %s   평균오차 %s° → %s°" % (g, pct(w.get("ok")), pct(v["ok"]),
                     "-" if w.get("mean") is None else "%.0f" % w["mean"], "-" if v["mean"] is None else "%.0f" % v["mean"]))
        bh = b["hits"]
        if bh.get("matched") and h.get("matched"):
            L.append("hit ±60ms 안 %d%% → %d%%, 크게 빠진 hit %d → %d" % (round(100 * bh["within60"]), round(100 * h["within60"]), bh["missing"], h["missing"]))
        new = [x for x in issues if x.get("new")]
        gone = s["before"]["gone"]
        sp = s["before"].get("spans", [])
        L.append("")
        L.append("편집으로 게임이 바뀐 곳 %d (두 녹화의 자세 12°↑ · 방향 25°↑ · 이동 · 높이 · 움직임 양이 다름; 안 건드린 곳은 자세 3° 안팎)" % len(sp))
        for x in sp:
            verdict = "-" if x["before"] is None or x["after"] is None else (
                "좋아짐" if x["after"] < x["before"] - 3 else ("나빠짐 ✗" if x["after"] > x["before"] + 3 else "비슷"))
            extra = ""
            if "이동" in x.get("what", []) and x.get("trv"):
                extra += ", 이동 속도 %.2f → %.2f 몸통/초" % tuple(x["trv"])
            if "움직임 양" in x.get("what", []):
                extra += ", 움직임 %d → %d°/s" % tuple(x["move"])
            L.append("   %s-%s  [%s] 자세 변화 최대 %d°%s, 원본과의 평균 오차 %s° → %s°  %s" % (
                ft(x["t0"]), ft(x["t1"]), "·".join(x.get("what", [])), round(x["change"]), extra, x["before"], x["after"], verdict))
        L.append("바뀐 곳에서 새로 생긴 항목 %d (아래 ★새), 없어진 항목 %d" % (len(new), len(gone)))
        for x in sorted(gone, key=lambda q: -q["sev"])[:15]:
            L.append("   고쳐짐: %s-%s [%s] %s" % (ft(x["t0"]), ft(x["t1"]), x["kind"], x["text"]))
    L.append("")
    L.append("## 먼저 볼 곳 (심한 순 %d)" % min(top, len(issues)))
    for it in sorted(issues, key=lambda x: -x["sev"])[:top]:
        L.append("#%-3d %s-%s  [%s]%s %s" % (it["id"], ft(it["t0"]), ft(it["t1"]), it["kind"], " ★새" if it.get("new") else "", it["text"]))
        L.append("      → %s" % it["hint"])
    L.append("")
    L.append("## 전체 (시간 순)")
    for it in issues:
        L.append("#%-3d %s-%s  [%s]%s %s" % (it["id"], ft(it["t0"]), ft(it["t1"]), it["kind"], " ★새" if it.get("new") else "", it["text"]))
    L.append("")
    L.append("※ 기계 판정입니다. 뷰어(review.html)에서 #번호를 눌러 0.5배속으로 겹쳐 보고 확정하세요.")
    L.append("  흔한 거짓 경보: 카메라 컷 · 줌, 다른 멤버가 가림, 손이 작게 찍힌 영상의 손, 카메라 쪽으로 뻗은 팔(깊이 오차).")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")


def r2(x, nd=2):
    return None if x is None or (isinstance(x, float) and math.isnan(x)) else round(float(x), nd)


def viewer_data(title, video_path, issues, summary, ctx):
    ts, BV, BG = ctx["ts"], ctx["BV"], ctx["BG"]
    stride = max(1, int(round(VSTEP / DT)))
    idx = np.arange(0, len(ts), stride)
    TV, imgV = ctx["TV"], ctx["imgV"]
    order = NAMES + ["HIP", "SHO", "EAR"]
    oi = [AI[n] for n in order]
    frames = {"t": [], "v": [], "g": [], "img": [], "yv": [], "yg": [], "e": [], "sc": []}
    # image torso length (px), smoothed over 2 s, for laying the game skeleton over the video
    tor = []
    for im in imgV:
        if im and all(k in im for k in ("lsho", "rsho", "lhip", "rhip")):
            sx, sy = (im["lsho"][0] + im["rsho"][0]) / 2, (im["lsho"][1] + im["rsho"][1]) / 2
            hx, hy = (im["lhip"][0] + im["rhip"][0]) / 2, (im["lhip"][1] + im["rhip"][1]) / 2
            tor.append(math.hypot(sx - hx, sy - hy))
        else:
            tor.append(np.nan)
    tor = np.array(tor)
    # the raw (camera) yaw of the video dancer, for the overlay
    for i in idx:
        t = float(ts[i])
        frames["t"].append(round(t, 3))
        v = BV[i, oi]
        frames["v"].append(None if np.isnan(v[:, 0]).all() or not ctx["valid"][i] else [r2(x) for x in v.flatten()])
        frames["g"].append([r2(x) for x in BG[i, oi].flatten()])
        k = int(np.searchsorted(TV, t))
        best = None
        for q in (k - 1, k):
            if 0 <= q < len(TV) and abs(TV[q] - t) <= 0.04 and imgV[q]:
                best = q
        if best is not None:
            im = imgV[best]
            frames["img"].append([r2(im.get(n, [None, None])[0], 1) if n in im else None for n in NAMES] +
                                 [r2(im.get(n, [None, None])[1], 1) if n in im else None for n in NAMES])
            lo, hi = max(0, best - 20), min(len(tor), best + 21)
            seg = tor[lo:hi]
            frames["sc"].append(r2(np.nanpercentile(seg, 80), 1) if np.any(~np.isnan(seg)) else None)
        else:
            frames["img"].append(None)
            frames["sc"].append(None)
        frames["yv"].append(r2(ctx["yawV"][i], 1))
        frames["yg"].append(r2(ctx["yawG"][i], 1))
        frames["e"].append([None if np.isnan(ctx["GE"][g][i]) else int(round(ctx["GE"][g][i])) for g in GROUPS])
    lagrows = {g: [[round(t, 2), l, c] for t, l, c, _ in rows] for g, rows in ctx["lags"].items()}
    amount = {g: [r2(x) for x in ctx["amount"][g][idx]] for g in GROUPS}
    grooves = {n: {"v": [r2(x, 3) for x in d["v"][idx]], "g": [r2(x, 3) for x in d["g"][idx]]} for n, d in ctx["grooves"].items()}
    return {
        "title": title, "video": video_path, "off": ctx["off"], "mirror": bool(ctx["use_m"]), "cam": ctx["cam"],
        "step": round(stride * DT, 4), "names": order, "groups": GROUPS, "thr": [THR[g] for g in GROUPS],
        "segs": [[s[0], order.index(s[1]) if s[1] in order else -1, order.index(s[2]) if s[2] in order else -1, GROUPS.index(s[3])]
                 for s in SEGS],
        "frames": frames, "issues": issues, "summary": summary, "hits": ctx["hits"],
        "beats": ctx["beats"]["beats"] if ctx["beats"] else [], "bpm": ctx["beats"]["bpm"] if ctx["beats"] else None,
        "lags": lagrows, "amount": amount, "grooves": grooves,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video_json")
    ap.add_argument("game_json")
    ap.add_argument("--video", help="원본 mp4 (뷰어 + 음악 박)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--title")
    ap.add_argument("--mirror", default="auto", choices=["auto", "on", "off"])
    ap.add_argument("--from", dest="t0", type=float)
    ap.add_argument("--to", dest="t1", type=float)
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--before", help="편집 전 게임 pose json: 고쳐진 것 / 새로 생긴 것을 표시")
    a = ap.parse_args()
    dv, dg = load(a.video_json), load(a.game_json)
    video = a.video or dv.get("video")
    title = a.title or dg.get("tag") or os.path.splitext(os.path.basename(a.video_json))[0]
    os.makedirs(a.out, exist_ok=True)
    t0, t1 = a.t0, a.t1
    db = load(a.before) if a.before else None
    if db:
        # both runs on the same time grid: the part the two recordings share (D-1893)
        def span(d):
            ts_ = [x["t"] for x in d["samples"] if x.get("p")]
            return min(ts_), max(ts_)
        (ga, gb), (ba, bb), (va, vb) = span(dg), span(db), span(dv)
        t0 = round(max(ga, ba, va, t0 if t0 is not None else -1e9) + 0.01, 2)
        t1 = round(min(gb, bb, vb, t1 if t1 is not None else 1e9) - 0.01, 2)
    issues, summary, ctx = analyse(dv, dg, a.mirror, t0, t1, video)
    if db:
        b_issues, b_summary, bctx = analyse(dv, db, a.mirror, t0, t1, video)
        spans = edit_spans(ctx, bctx)
        tag_before(issues, b_issues, spans, summary.get("game_gaps") or [])
        summary["before"] = {"summary": b_summary, "gone": [x for x in b_issues if x.get("gone")], "spans": spans}
    write_report(os.path.join(a.out, "검토_리포트.txt"), title, issues, summary, a.top)
    data = viewer_data(title, os.path.abspath(video) if video else None, issues, summary, ctx)
    with open(os.path.join(HERE, "viewer.html"), encoding="utf-8") as f:
        html = f.read()
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    html = html.replace("/*__DATA__*/null", blob).replace("__TITLE__", title)
    with open(os.path.join(a.out, "review.html"), "w", encoding="utf-8") as f:
        f.write(html)
    with open(os.path.join(a.out, "issues.json"), "w", encoding="utf-8") as f:
        json.dump({"summary": summary, "issues": issues}, f, ensure_ascii=False, indent=1)
    h = summary["hits"]
    print("항목 %d개 -> %s" % (len(issues), a.out))
    print("전체 박자 %s ms, hit %d/%d 짝 (중앙값 %s ms, ±60ms %s%%)" % (
        "-" if summary["lag_overall"] is None else "%+d" % round(summary["lag_overall"] * 1000), h["matched"], h["video"],
        h["median_ms"], "-" if h["within60"] is None else round(100 * h["within60"])))


if __name__ == "__main__":
    main()
