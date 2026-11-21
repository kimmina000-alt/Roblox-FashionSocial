"""Four 1-second EDM sounds for the user to pick from (D-1818k, user 2026-11-21: "1초짜리 edm 음 4가지 가지고 와 봐").

Made from scratch (no samples, nothing to license). 44.1 kHz mono WAVs, each exactly 1.0 s:
  edm_1_supersaw.wav  a wide detuned supersaw chord stab (A minor) with a reverb tail
  edm_2_riser.wav     a white-noise + pitch riser that ends in a hit with a sub drop
  edm_3_wobble.wav    a dubstep wobble bass (LFO on the filter, 2 wobbles)
  edm_4_pluck.wav     a bright future-bass pluck arpeggio (A C E A, 16ths) with echo
Usage: python tools/art/edm_1s.py [out_dir]   (default docs/04_ART/sfx)
"""
import os
import sys
import wave

import numpy as np

SR = 44100
N = SR  # 1 s
t = np.arange(N) / SR
rng = np.random.default_rng(11)


def saw(freq, tt, cents=0.0, phase=0.0):
    f = freq * 2 ** (cents / 1200)
    return 2 * ((tt * f + phase) % 1.0) - 1


def lowpass(x, cutoff):
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev += a[i] * (x[i] - prev)
        y[i] = prev
    return y


def reverb(x, mix=0.35):
    out = x.copy()
    for d, g in ((0.031, 0.5), (0.047, 0.42), (0.067, 0.36), (0.089, 0.3), (0.113, 0.25), (0.149, 0.2), (0.197, 0.15)):
        n = int(SR * d)
        out[n:] += x[:-n] * g * mix
    return out


def echo(x, delay=0.125, fb=0.4, times=4):
    out = x.copy()
    n = int(SR * delay)
    for k in range(1, times + 1):
        if n * k >= len(x):
            break
        out[n * k:] += x[: len(x) - n * k] * fb ** k
    return out


def finish(x):
    x = x[:N] if len(x) >= N else np.pad(x, (0, N - len(x)))
    fade = int(SR * 0.03)
    x[-fade:] *= np.linspace(1, 0, fade)
    x[:64] *= np.linspace(0, 1, 64)
    return x / (np.max(np.abs(x)) or 1) * 0.89


def write(path, x):
    data = (finish(x) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(path)


def supersaw():
    chord = [220.0, 261.63, 329.63, 440.0]  # A3 C4 E4 A4
    x = np.zeros(N)
    for f in chord:
        for cents in (-22, -11, -4, 0, 4, 11, 22):
            x += saw(f, t, cents, rng.random())
    x /= len(chord) * 7
    cutoff = 1500 + 9000 * np.exp(-t / 0.18)
    x = lowpass(lowpass(x, cutoff), cutoff)
    env = np.minimum(t / 0.004, 1) * np.exp(-t / 0.28)
    return reverb(x * env, 0.5)


def riser():
    rise_end = 0.62
    r = t < rise_end
    noise = rng.uniform(-1, 1, N)
    cut = 300 + 12000 * (t / rise_end) ** 2
    nz = lowpass(noise, np.where(r, cut, 300)) * np.where(r, (t / rise_end) ** 1.5, 0) * 0.8
    freq = 200 + 1400 * (t / rise_end) ** 2
    phase = np.cumsum(freq) / SR
    tone = (2 * (phase % 1.0) - 1) * np.where(r, (t / rise_end) ** 2, 0) * 0.35
    th = np.clip(t - rise_end, 0, None)
    hit_on = ~r
    sub = np.sin(2 * np.pi * np.cumsum(55 + 90 * np.exp(-th / 0.04)) / SR) * np.exp(-th / 0.22) * hit_on
    crack = rng.uniform(-1, 1, N) * np.exp(-th / 0.03) * hit_on * 0.6
    return reverb(nz + tone + sub + crack, 0.3)


def wobble():
    f = 55.0  # A1
    x = saw(f, t) * 0.6 + saw(f * 1.005, t, 0, 0.3) * 0.6 + np.sin(2 * np.pi * f * t) * 0.5
    lfo = 0.5 - 0.5 * np.cos(2 * np.pi * 2.0 * t)  # 2 wobbles in 1 s
    cutoff = 120 + 2600 * lfo
    x = lowpass(lowpass(x, cutoff), cutoff)
    x = np.tanh(x * 3)  # grit
    env = np.minimum(t / 0.01, 1) * np.where(t > 0.85, np.exp(-(t - 0.85) / 0.05), 1)
    return x * env


def pluck():
    notes = [440.0, 523.25, 659.25, 880.0]  # A C E A
    step = 0.125
    x = np.zeros(N)
    for i, f in enumerate(notes):
        start = int(SR * i * step)
        tt = t[: N - start]
        s = (saw(f, tt, -8) + saw(f, tt, 8) + 0.5 * np.sin(2 * np.pi * f * 2 * tt)) / 2.5
        s = lowpass(s, 800 + 9000 * np.exp(-tt / 0.05)) * np.exp(-tt / 0.09)
        x[start:] += s
    return reverb(echo(x, 0.125 * 1.5, 0.35, 3), 0.35)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("docs", "04_ART", "sfx")
    os.makedirs(out, exist_ok=True)
    write(os.path.join(out, "edm_1_supersaw.wav"), supersaw())
    write(os.path.join(out, "edm_2_riser.wav"), riser())
    write(os.path.join(out, "edm_3_wobble.wav"), wobble())
    write(os.path.join(out, "edm_4_pluck.wav"), pluck())
