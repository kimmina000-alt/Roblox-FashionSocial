"""Per-song button sounds for "오늘의 곡 도전" (D-1984; user 2026-11-22: "노래에 맞는 드럼 소리나
edm 소리 ai로 만든 후 리듬 게임에 적용").

Made from scratch (numpy synthesis, no samples). Four kits, four buttons each, every pitched sound in C
(the game turns it to the song's key with PlaybackSpeed, Shared/DanceScoreSounds.lua):
  edm    supersaw power-chord stabs (the edm_5_stab sound the user liked)   I5 / IV5 / V5 / I5 high
  trap   tuned 808 boom, snare, dark brass stab, clap                         (hip-hop songs)
  pop    bright plucks + a bell                                               I5 / IV5 / V5 / bell
  retro  synth-brass stabs + an orchestra hit                                 (2009-2010 songs, funk)
Power chords (root + fifth) only: they sit in a major or a minor key alike, so a random chart never
plays a wrong third. Every file is 0.42 s, 2-3 ms attack, loudness matched to edm_5_stab.

Usage: python tools/art/dance_kits.py [out_dir]          (default docs/04_ART/sfx/kits)
       python tools/art/dance_kits.py --preview songs.json out_dir
           song excerpts with the kit on the beats (by ear: does it sit in the song?)
"""
import json
import os
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import edm_1s as base  # noqa: E402

SR = base.SR
DUR = 0.42
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(1122)
C3 = 130.8128


def hz(semis_from_c3):
    return C3 * 2 ** (semis_from_c3 / 12)


def env(attack, decay):
    return np.minimum(t / attack, 1) * np.exp(-t / decay)


def supersaw(freqs, spread=(-16, -6, 0, 6, 16)):
    x = np.zeros(N)
    for f in freqs:
        for c in spread:
            x += base.saw(f, t, c, rng.random())
    return x / (len(freqs) * len(spread))


def power(root):  # root, fifth, octave (semitones from C3)
    return [hz(root), hz(root + 7), hz(root + 12)]


def noise():
    return rng.uniform(-1, 1, N)


def highpass(x, cutoff):
    return x - base.lowpass(x, cutoff)


# ---- edm ----
def edm_stab(root, bright=1.0):
    x = supersaw(power(root))
    cut = 1800 + 11000 * bright * np.exp(-t / 0.07)
    x = base.lowpass(base.lowpass(x, cut), cut)
    return base.reverb(x * env(0.002, 0.11), 0.4)


# ---- trap ----
def boom808(root):
    f0 = hz(root - 24)  # C1..: the 808's note
    freq = f0 + 140 * np.exp(-t / 0.025)
    x = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t / 0.28)
    x = np.tanh(x * 2.2)
    click = base.lowpass(noise(), 4000) * np.exp(-t / 0.004) * 0.4
    return x + click


def snare():
    body = np.sin(2 * np.pi * np.cumsum(185 + 60 * np.exp(-t / 0.01)) / SR) * np.exp(-t / 0.06)
    nz = highpass(base.lowpass(noise(), 9000), 1500) * np.exp(-t / 0.09)
    return base.reverb(body * 0.6 + nz * 0.9, 0.3)


def brass_dark(root):
    x = supersaw(power(root), (-10, 0, 10))
    cut = 900 + 3200 * np.exp(-t / 0.05)
    x = base.lowpass(base.lowpass(x, cut), cut)
    return base.reverb(x * env(0.003, 0.12), 0.3)


def clap():
    x = np.zeros(N)
    for k, d in enumerate((0.0, 0.009, 0.018, 0.027)):
        n = int(SR * d)
        burst = highpass(base.lowpass(noise(), 7000), 900) * np.exp(-np.maximum(t - d, 0) / (0.012 if k < 3 else 0.11))
        x[n:] += burst[: N - n]
    return base.reverb(x, 0.45)


# ---- pop ----
def pluck(root):
    x = supersaw([hz(root + 12), hz(root + 19), hz(root + 24)], (-8, 0, 8))
    cut = 1200 + 9000 * np.exp(-t / 0.03)
    x = base.lowpass(base.lowpass(x, cut), cut)
    return base.echo(base.reverb(x * env(0.002, 0.09), 0.35), 0.11, 0.25, 2)


def bell(root):
    f = hz(root + 24)
    mod = np.sin(2 * np.pi * f * 3.5 * t) * 2.2 * np.exp(-t / 0.12)
    x = np.sin(2 * np.pi * f * t + mod) * env(0.002, 0.16)
    x += np.sin(2 * np.pi * f * 2 * t) * env(0.002, 0.06) * 0.3
    return base.reverb(x, 0.35)


# ---- retro ----
def brass(root):
    freqs = power(root)
    x = np.zeros(N)
    for f in freqs:
        for c in (-8, 0, 8):
            x += base.saw(f, t, c, rng.random()) + 0.5 * np.sign(np.sin(2 * np.pi * f * 2 ** (c / 1200) * t))
    x /= len(freqs) * 3
    cut = 700 + 5000 * np.minimum(t / 0.02, 1) * np.exp(-t / 0.12)  # the "bwah" of a brass section
    x = base.lowpass(base.lowpass(x, cut), cut)
    return base.reverb(x * env(0.003, 0.14), 0.4)


def orch_hit(root):
    x = supersaw([hz(root - 12), hz(root), hz(root + 7), hz(root + 12), hz(root + 19)], (-12, 0, 12))
    x = base.lowpass(x, 2500 + 8000 * np.exp(-t / 0.05))
    nz = base.lowpass(noise(), 6000) * np.exp(-t / 0.02) * 0.5
    return base.reverb((x + nz) * env(0.002, 0.13), 0.55)


# lane sounds: (file name, maker, pitched)
KITS = {
    "edm": [("edm_1", lambda: edm_stab(0), True), ("edm_2", lambda: edm_stab(5), True),
            ("edm_3", lambda: edm_stab(7), True), ("edm_4", lambda: edm_stab(12, 1.2), True)],
    "trap": [("trap_1_808", lambda: boom808(0), True), ("trap_2_snare", snare, False),
             ("trap_3_brass", lambda: brass_dark(0), True), ("trap_4_clap", clap, False)],
    "pop": [("pop_1", lambda: pluck(0), True), ("pop_2", lambda: pluck(5), True),
            ("pop_3", lambda: pluck(7), True), ("pop_4_bell", lambda: bell(0), True)],
    "retro": [("retro_1", lambda: brass(0), True), ("retro_2", lambda: brass(5), True),
              ("retro_3", lambda: brass(7), True), ("retro_4_hit", lambda: orch_hit(0), True)],
}

REF_RMS = None  # loudness of edm_5_stab's first 150 ms (the volume the user set is for it)


def loud(x):
    k = int(SR * 0.15)
    return float(np.sqrt(np.mean(x[:k] ** 2)))


GAIN = {"trap_1_808": 2.2}  # a low sine sounds quieter than its RMS says


def finish(x, gain=1.0):
    x = x[:N] if len(x) >= N else np.pad(x, (0, N - len(x)))
    fade = int(SR * 0.04)
    x[-fade:] *= np.linspace(1, 0, fade)
    x[:32] *= np.linspace(0, 1, 32)
    x = x / (np.max(np.abs(x)) or 1)
    if REF_RMS:  # same loudness as edm_5_stab, never clipping
        x *= min(REF_RMS * gain / (loud(x) or 1), 0.95 / np.max(np.abs(x)))
    return x


def write(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def read(path):
    with wave.open(path) as w:
        return np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32767


def make(out):
    global REF_RMS
    ref = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "04_ART", "sfx", "edm_5_stab.wav")
    REF_RMS = loud(read(ref))
    os.makedirs(out, exist_ok=True)
    for kit, lanes in KITS.items():
        for name, maker, _ in lanes:
            path = os.path.join(out, name + ".wav")
            write(path, finish(maker(), GAIN.get(name, 1.0)))
            print(path)


# ---- previews: an excerpt of the song with its kit on the beats ----
def decode(path, sr=SR):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, "<f4").astype(np.float64)


def beat_phase(x, bpm, start, length):
    seg = x[int(start * SR): int((start + length) * SR)]
    hop = 256
    fr = np.lib.stride_tricks.sliding_window_view(seg, 1024)[::hop] * np.hanning(1024)
    s = np.log1p(np.abs(np.fft.rfft(fr, axis=1))[:, :60])  # low end: the kick
    flux = np.maximum(np.diff(s, axis=0), 0).sum(1)
    beat = 60 / bpm
    best, best_v = 0.0, -1
    for ph in np.arange(0, beat, 0.005):
        idx = ((np.arange(ph, length - 0.1, beat)) * SR / hop).astype(int)
        idx = idx[idx < len(flux)]
        v = flux[idx].sum()
        if v > best_v:
            best, best_v = ph, v
    return start + best


def resample(x, speed):
    n = int(len(x) / speed)
    return np.interp(np.arange(n) * speed, np.arange(len(x)), x)


def preview(songs_json, kits_dir, out, assign):
    from song_key import SONGS, SRC  # noqa
    import glob
    files = glob.glob(os.path.join(SRC, "*.mp3"))
    songs = json.load(open(songs_json, encoding="utf8"))
    os.makedirs(out, exist_ok=True)
    for sid, info in songs.items():
        kit = assign.get(int(sid), "edm")
        part = SONGS[int(sid)][1]
        x = decode([f for f in files if part in os.path.basename(f)][0])
        start = len(x) / SR * 0.42
        length = 14.0
        t0 = beat_phase(x, info["bpm"], start, length)
        seg = x[int(start * SR): int((start + length) * SR)].copy()
        semis = info["root"] if info["root"] <= 6 else info["root"] - 12
        lanes = [read(os.path.join(kits_dir, name + ".wav")) for name, _, _ in KITS[kit]]
        pitched = [p for _, _, p in KITS[kit]]
        song_rms = float(np.sqrt(np.mean(seg ** 2)))
        hits = np.zeros(len(seg) + SR)
        beat = 60 / info["bpm"]
        r = np.random.default_rng(int(sid) % 1000)
        k = 0
        while True:
            tt = t0 - start + k * beat
            if tt > length - 0.5:
                break
            if k % 8 != 7:
                lane = int(r.integers(4))
                s = lanes[lane]
                if pitched[lane]:
                    s = resample(s, 2 ** (semis / 12))
                n = int(tt * SR)
                hits[n: n + len(s)] += s
            k += 1
        mix = seg + hits[: len(seg)] * (song_rms / 0.18) * 0.55
        mix /= max(1.0, np.max(np.abs(mix)) / 0.95)
        name = f"{info['title']}_{kit}_{info['key']}{'m' if info['mode'] == 'minor' else ''}".replace(" ", "_")
        wav = os.path.join(out, name + ".wav")
        write(wav, mix)
        subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", wav, "-b:a", "160k", wav[:-4] + ".mp3"], check=True)
        os.remove(wav)
        print(wav[:-4] + ".mp3")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--preview":
        sys.path.insert(0, os.path.dirname(__file__))
        assign = json.load(open(sys.argv[4], encoding="utf8")) if len(sys.argv) > 4 else {}
        assign = {int(k): v for k, v in assign.items()}
        preview(sys.argv[2], os.path.join("docs", "04_ART", "sfx", "kits"), sys.argv[3], assign)
    else:
        make(sys.argv[1] if len(sys.argv) > 1 else os.path.join("docs", "04_ART", "sfx", "kits"))
