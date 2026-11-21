"""Cyberpunk EDM hit sounds for 오늘의 곡 도전 (D-1818f, user 2026-11-21: "사이버펑크 edm 같은 소리면 좋겠는데").

Made here from scratch (no samples), so there is nothing to license. Writes 44.1 kHz mono WAVs:
  dance_hit.wav      GREAT / a normal hit: a short detuned saw stab (root + fifth + octave) with a fast
                     closing filter, a noise click on top and a light bit crush
  dance_perfect.wav  PERFECT: the same stab an octave brighter + a square "ping" + one echo
  dance_hold.wav     the end of a held note: a rising filter sweep into a short stab
Usage: python tools/art/dance_sfx.py [out_dir]   (default docs/04_ART/sfx)
Upload them as Audio on the Vantablack_Dev account and put the ids in DanceScoreConfig
(HitSound / PerfectSound / HoldSound).
"""
import os
import sys
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def saw(freq, t, detune_cents=0.0):
    f = freq * 2 ** (detune_cents / 1200)
    return 2 * ((t * f) % 1.0) - 1


def square(freq, t):
    return np.sign(np.sin(2 * np.pi * freq * t))


def lowpass(x, cutoff):
    """One-pole low-pass with a cutoff that can change every sample (array or number)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    y = np.zeros_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        a = 1 - np.exp(-2 * np.pi * cutoff[i] / SR)
        prev += a * (v - prev)
        y[i] = prev
    return y


def crush(x, bits=7):
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def stab(root, length, cutoff_from, cutoff_to, sweep):
    t = np.arange(int(SR * length)) / SR
    voices = []
    for mult in (1, 1.5, 2):  # root, fifth, octave: no third, so it sits on any key
        for cents in (-14, 0, 14):
            voices.append(saw(root * mult, t + rng.random() * 0.01, cents))
    x = np.mean(voices, axis=0)
    cutoff = cutoff_to + (cutoff_from - cutoff_to) * np.exp(-t / sweep)
    x = lowpass(lowpass(x, cutoff), cutoff)
    env = np.minimum(t / 0.002, 1) * np.exp(-t / (length * 0.32))
    return x * env, t


def click(n_ms=6):
    n = int(SR * n_ms / 1000)
    c = rng.uniform(-1, 1, n) * np.linspace(1, 0, n) ** 2
    return c


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def fade_out(x, ms=8):
    n = int(SR * ms / 1000)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write(path, x):
    x = fade_out(normalize(x))
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(path, f"{len(x) / SR:.3f} s")


def hit():
    x, t = stab(220.0, 0.16, 9000, 900, 0.025)
    c = click()
    x[: len(c)] += c * 0.5
    return crush(x, 8)


def perfect():
    x, t = stab(440.0, 0.26, 12000, 1400, 0.04)
    ping = square(1760.0, t) * np.exp(-t / 0.05) * 0.35
    ping = lowpass(ping, 6000)
    x = x + ping
    c = click(4)
    x[: len(c)] += c * 0.45
    echo = np.zeros_like(x)
    d = int(SR * 0.075)
    echo[d:] = x[:-d] * 0.35
    return crush(x + echo, 8)


def hold_end():
    rise_len = 0.12
    t = np.arange(int(SR * rise_len)) / SR
    noise = rng.uniform(-1, 1, len(t))
    rise = lowpass(noise, 500 + 9000 * (t / rise_len) ** 2) * (t / rise_len) * 0.5
    s, _ = stab(330.0, 0.22, 11000, 1200, 0.035)
    return crush(np.concatenate([rise, s]), 8)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("docs", "04_ART", "sfx")
    os.makedirs(out, exist_ok=True)
    write(os.path.join(out, "dance_hit.wav"), hit())
    write(os.path.join(out, "dance_perfect.wav"), perfect())
    write(os.path.join(out, "dance_hold.wav"), hold_end())
