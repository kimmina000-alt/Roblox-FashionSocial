"""0.5-second EDM sounds (D-1818l, user 2026-11-21: "3은 앞에 0.5초만 줘 봐 / 0.5초짜리 edm 음도 줘 4개").

Made from scratch (no samples). 44.1 kHz mono WAVs, each exactly 0.5 s:
  edm_3_wobble_half.wav  the first 0.5 s of edm_3_wobble.wav (one wobble), with a short fade at the end
  edm_5_stab.wav         a bright supersaw chord stab (A minor), short reverb
  edm_6_zap.wav          a laser zap: a square wave diving from high to low
  edm_7_808.wav          a distorted 808 boom with a click on top
  edm_8_pump.wav         a supersaw chord pumping twice (sidechain feel, 1/8 notes at 120 bpm)
Usage: python tools/art/edm_half.py [out_dir]   (default docs/04_ART/sfx; run edm_1s.py first for 3)
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import edm_1s as base  # noqa: E402

SR = base.SR
N = SR // 2
t = np.arange(N) / SR
rng = np.random.default_rng(23)


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


def chord_voices(tt, cents_list=(-18, -7, 0, 7, 18)):
    chord = [220.0, 261.63, 329.63, 440.0]
    x = np.zeros(len(tt))
    for f in chord:
        for cents in cents_list:
            x += base.saw(f, tt, cents, rng.random())
    return x / (len(chord) * len(cents_list))


def stab():
    x = chord_voices(t)
    cutoff = 2000 + 11000 * np.exp(-t / 0.08)
    x = base.lowpass(base.lowpass(x, cutoff), cutoff)
    env = np.minimum(t / 0.003, 1) * np.exp(-t / 0.12)
    return base.reverb(x * env, 0.4)


def zap():
    freq = 80 + 2400 * np.exp(-t / 0.07)
    phase = np.cumsum(freq) / SR
    x = np.sign(np.sin(2 * np.pi * phase)) * 0.6 + np.sin(2 * np.pi * phase * 0.5) * 0.4
    x = base.lowpass(x, 6000)
    env = np.minimum(t / 0.002, 1) * np.exp(-t / 0.16)
    return base.echo(x * env, 0.09, 0.3, 2)


def boom808():
    freq = 48 + 110 * np.exp(-t / 0.03)
    phase = np.cumsum(freq) / SR
    x = np.sin(2 * np.pi * phase) * np.exp(-t / 0.3)
    x = np.tanh(x * 2.5)
    click = rng.uniform(-1, 1, N) * np.exp(-t / 0.004) * 0.5
    return x + base.lowpass(click, 5000)


def pump():
    x = chord_voices(t)
    x = base.lowpass(x, 5000)
    beat = 0.25  # 1/8 at 120 bpm
    ph = (t % beat) / beat
    duck = np.minimum(ph / 0.35, 1) ** 2  # quiet right after each kick, then swells
    kick_t = t % beat
    kick = np.sin(2 * np.pi * np.cumsum(50 + 120 * np.exp(-kick_t / 0.02)) / SR) * np.exp(-kick_t / 0.08)
    return x * duck * 0.9 + kick * 0.7


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("docs", "04_ART", "sfx")
    os.makedirs(out, exist_ok=True)
    with wave.open(os.path.join(out, "edm_3_wobble.wav")) as w:
        wob = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32767
    write(os.path.join(out, "edm_3_wobble_half.wav"), wob[:N].copy())
    write(os.path.join(out, "edm_5_stab.wav"), stab())
    write(os.path.join(out, "edm_6_zap.wav"), zap())
    write(os.path.join(out, "edm_7_808.wav"), boom808())
    write(os.path.join(out, "edm_8_pump.wav"), pump())
