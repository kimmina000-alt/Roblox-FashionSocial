"""Beats of every choreographed song for 오늘의 곡 도전 (D-1818x, user 2026-11-22: "내가 설정 안 해도 리듬 게임
알아서 안무 있는 곡으로 랜덤으로 달라지게").

For each song in SONGS (soundId -> original mp3 in D:\\Roblox\\오후\\음원, whose seconds are the song clock the
choreography's `at` is on, D-876), this finds the tempo and the first beat:
  1. decode to mono 22.05 kHz with ffmpeg, onset strength = positive spectral flux (hop 256)
  2. tempo: autocorrelation of the onset curve, 85..170 bpm
  3. refine bpm (+-1.5, step 0.005) and phase together: the grid whose beats land on the strongest
     onsets over the whole song (K-pop keeps one tempo)
It writes src/ReplicatedStorage/FashionGame/Shared/DanceScoreSongs.lua (soundId = { bpm, firstBeat, score })
and prints a table; NEON is the check (measured from the stage video in D-1816: 129.99 bpm, first beat
-0.913).
Usage: python tools/choreo/dance_beats.py [--only <soundId>]
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
import soundfile as sf

MP3 = r"D:\Roblox\오후\음원"
SR = 22050
HOP = 256
FPS = SR / HOP

# soundId: (title, mp3 file id prefix)
SONGS = {
    134942349436280: ("BAD", "ATEEZ", "uFuvYOzl0kg"),
    128270208751659: ("소원을 말해봐(Genie)", "소녀시대", "65pNUeEuYB8"),
    70738014182544: ("Get A Guitar", "RIIZE", "krlP8QK4uLY"),
    85204387077332: ("Love 119", "RIIZE", "oXh6zz5BA4Q"),
    119002946047943: ("캐치 캐치", "YENA", "VtBZhsuqoWc"),
    97032815457241: ("Lemon Tang", "Hearts2Hearts", "LjvPo6zUn6s"),
    101586065131501: ("Lemonade", "aespa", "yWBWPlmbVgk"),
    140713297574648: ("NEON", "A2O LITE", "tK6Ze7ngQQs"),
    139044453511745: ("체포하겠어", "ILLIT", "bSavDIXZPJg"),
    139330220515727: ("LOVE-ATTACK", "RESCENE", "VnqgmOJaMGc"),
    135553051649506: ("Looks Can Kill", "IVE", "Wp4zyaDlWIk"),
    75344866720031: ("갑자기", "IOI", "Ulyes7pJRLk"),
    98124521559769: ("I SPY", "NCT WISH", "YKPo7k1-rdI"),
    76034005809699: ("REDRED", "CORTIS", "ZF49-rKzTLk"),
    94774089824958: ("ANIMAL", "BOYNEXTDOOR", "g8gD2GVcg0M"),
    140273876429390: ("Pretty Girl", "RESCENE", "j6ybyVa_5N4"),
    131620527618857: ("Pop Off", "키키", "sigoXkCIzsY"),
    112509101263761: ("With", "RESCENE", "GnKDPfTd9UY"),
    86115718533153: ("CRASH", "ALLDAY PROJECT", "GJbGY8gMkL0"),
    94024099429072: ("SHOCK", "TREASURE", "rp7Q7_m_B-8"),
    74619423082896: ("백화요란", "RESCENE", "re8HXvsK3xM"),
    136570075901439: ("BANG", "After School", "AEH1m2ez5hw"),
    81736514719301: ("Unbelievable", "H1 KEY", "aj_2goO-n8A"),
    102947379971628: ("Boogie Woogie", "NCT DREAM", "2Qhc7UPX_5Y"),
    129638210426239: ("내 이름을 불러줘(Call My Name)", "TWS", "V8aLu69DTms"),
    # (D-2082, user 2026-11-25: "새로 추가된 곡들 추가하고") the newer choreographed songs (Magic / GiiiRIP wait for
    # their choreography: the game only picks songs the neon stage can dance)
    88799517182805: ("Potion", "AND2BLE", "XqP5O4rzCvo"),
    80492816031335: ("It's Me", "ILLIT", "RwUKqYWyzNc"),
    84753987256309: ("Abracadabra", "Brown Eyed Girls", "dWsWbd7xauA"),
    124810692241835: ("Magic", "Secret", "Q5HKuivlwEo"),
    84573541048803: ("GiiiRIP", "BIGBANG", "M6kZttNNRkM"),
}


def find_mp3(prefix):
    for name in os.listdir(MP3):
        if name.startswith("YTDown.com_YouTube_Media_" + prefix + "_"):
            return os.path.join(MP3, name)
    return None


def load(path):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "a.wav")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-ac", "1", "-ar", str(SR), wav], check=True)
        x, _ = sf.read(wav, dtype="float32")
    return x


def onset_curve(x):
    n_fft = 1024
    win = np.hanning(n_fft).astype(np.float32)
    frames = 1 + (len(x) - n_fft) // HOP
    idx = np.arange(n_fft)[None, :] + HOP * np.arange(frames)[:, None]
    spec = np.abs(np.fft.rfft(x[idx] * win, axis=1))
    spec = np.log1p(100 * spec)
    flux = np.maximum(spec[1:] - spec[:-1], 0).sum(axis=1)
    flux = np.concatenate([[0], flux])
    # remove the slow loudness trend, keep the hits
    k = int(FPS * 0.5)
    trend = np.convolve(flux, np.ones(k) / k, mode="same")
    o = np.maximum(flux - trend, 0)
    return o / (o.max() or 1)


def tempo_guess(o):
    o = o - o.mean()
    ac = np.correlate(o, o, mode="full")[len(o) - 1:]
    best, best_v = None, -1
    for bpm in np.arange(85, 170.01, 0.25):
        lag = FPS * 60 / bpm
        v = 0
        for m in (1, 2, 4):
            i = lag * m
            lo = int(i)
            if lo + 1 >= len(ac):
                break
            v += ac[lo] + (ac[lo + 1] - ac[lo]) * (i - lo)
        if v > best_v:
            best, best_v = bpm, v
    return best


def grid_score(o, bpm, phase, t0, t1):
    beat = 60 / bpm
    ts = np.arange(phase + np.ceil((t0 - phase) / beat) * beat, t1, beat)
    f = ts * FPS
    lo = np.floor(f).astype(int)
    lo = lo[(lo >= 0) & (lo + 1 < len(o))]
    # the strongest onset within +-1 frame of each beat
    v = np.maximum(np.maximum(o[lo], o[lo + 1]), o[np.maximum(lo - 1, 0)])
    return float(v.mean())


def refine(o, guess):
    t0, t1 = 5.0, len(o) / FPS - 5.0
    best = (-1, guess, 0.0)
    for bpm in np.arange(guess - 1.5, guess + 1.5001, 0.01):
        beat = 60 / bpm
        for phase in np.arange(0, beat, 0.005):
            s = grid_score(o, bpm, phase, t0, t1)
            if s > best[0]:
                best = (s, bpm, phase)
    s, bpm, phase = best
    for b2 in np.arange(bpm - 0.012, bpm + 0.0121, 0.001):
        beat = 60 / b2
        for p2 in np.arange(phase - 0.012, phase + 0.0121, 0.001):
            v = grid_score(o, b2, p2 % beat, t0, t1)
            if v > s:
                s, bpm, phase = v, b2, p2 % beat
    return bpm, phase, s


def measure(sound_id):
    title, artist, prefix = SONGS[sound_id]
    path = find_mp3(prefix)
    if not path:
        return None
    o = onset_curve(load(path))
    g = tempo_guess(o)
    bpm, phase, score = refine(o, g)
    # a frame's time is its window's start; a hit shows most where it crosses the window's middle
    phase += 512 / SR
    # the first beat in song seconds at or before 0 (the chart walks forward from it)
    first = phase - 60 / bpm * np.ceil(phase / (60 / bpm))
    return {"title": title, "artist": artist, "bpm": round(float(bpm), 3), "firstBeat": round(float(first), 3),
            "score": round(score, 3), "guess": g}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_module(results):
    lines = [
        "--!strict",
        "-- 오늘의 곡 도전: beats of every choreographed song (D-1818x). GENERATED by tools/choreo/dance_beats.py from",
        "-- the original mp3s (D:\\Roblox\\오후\\음원; their seconds = the song clock the choreography's `at` is on).",
        "-- Do not edit by hand: run the tool again. score = how strongly the onsets sit on the grid (0..1);",
        "-- DanceScoreConfig leaves out songs under its MinBeatScore.",
        "",
        "return {",
    ]
    for sid, r in sorted(results.items(), key=lambda kv: kv[1]["title"]):
        lines.append("\t[%d] = { title = %s, artist = %s, bpm = %s, firstBeat = %s, score = %s }," % (
            sid, lua_str(r["title"]), lua_str(r["artist"]), r["bpm"], r["firstBeat"], r["score"]))
    lines.append("}")
    lines.append("")
    path = os.path.join("src", "ReplicatedStorage", "FashionGame", "Shared", "DanceScoreSongs.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote", path)


if __name__ == "__main__":
    only = None
    if "--only" in sys.argv:
        only = int(sys.argv[sys.argv.index("--only") + 1])
    results = {}
    for sid in SONGS:
        if only and sid != only:
            continue
        r = measure(sid)
        if not r:
            print(sid, "no mp3")
            continue
        results[sid] = r
        print("%-16s %-30s bpm %8.3f (guess %6.2f) first %7.3f score %.3f" % (sid, r["title"], r["bpm"], r["guess"], r["firstBeat"], r["score"]), flush=True)
    if not only:
        write_module(results)
