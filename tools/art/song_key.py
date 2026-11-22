"""Key, tempo and colour of the rhythm-game songs (D-1984).

Decodes each original mp3 (D:/Roblox/오후/음원) with ffmpeg, then numpy only:
  key   = chroma (constant-Q-ish bins from an FFT) against the Krumhansl-Schmuckler profiles
  bpm   = autocorrelation of the onset envelope (70..180, folded to 80..160)
  bass  = share of energy under 150 Hz (808 / hip-hop songs are high), bright = spectral centroid
Usage: python tools/art/song_key.py [out.json]
"""
import glob
import json
import os
import subprocess
import sys

import numpy as np

SR = 22050
SRC = "D:/Roblox/오후/음원"
# soundId -> (title, a unique part of the mp3 name)
SONGS = {
    134942349436280: ("BAD-ATEEZ", "ATEEZ-에이티즈-BAD"),
    128270208751659: ("Genie-소녀시대", "소원을-말해봐"),
    70738014182544: ("Get A Guitar-RIIZE", "Get-A-Guitar"),
    85204387077332: ("Love 119-RIIZE", "Love-119"),
    119002946047943: ("Catch Catch-YENA", "캐치-캐치"),
    97032815457241: ("Lemon Tang-Hearts2Hearts", "Lemon-Tang"),
    101586065131501: ("Lemonade-aespa", "aespa-에스파-Lemonade"),
    140713297574648: ("NEON-A2O LITE", "A2O-LITE-NEON"),
    139044453511745: ("체포하겠어-ILLIT", "체포하겠어"),
    139330220515727: ("LOVE-ATTACK-RESCENE", "LOVE-ATTACK"),
    135553051649506: ("Looks Can Kill-IVE", "Looks-Can-Kill"),
    75344866720031: ("갑자기-IOI", "갑자기"),
    98124521559769: ("I SPY-NCT WISH", "I-SPY"),
    76034005809699: ("REDRED-CORTIS", "REDRED"),
    94774089824958: ("ANIMAL-BOYNEXTDOOR", "ANIMAL"),
    140273876429390: ("Pretty Girl-RESCENE", "Pretty-Girl"),
    131620527618857: ("Pop Off-KiiiKiii", "Pop-Off"),
    112509101263761: ("With-RESCENE", "RESCENE-리센느-With"),
    86115718533153: ("CRASH-ALLDAY PROJECT", "CRASH"),
    117439533883778: ("BiiiG BiiiG-BIGBANG", "BiiiG"),
    94024099429072: ("SHOCK-TREASURE", "TREASURE-트레저-SHOCK"),
    74619423082896: ("백화요란-RESCENE", "백화요란"),
    136570075901439: ("BANG-After School", "bang-뱅-BANG"),
    127479755620167: ("SHEESH-BABYMONSTER", "SHEESH"),
    81736514719301: ("Unbelievable-H1 KEY", "Unbelievable"),
    102947379971628: ("Boogie Woogie-NCT DREAM", "Boogie-Woogie"),
    129638210426239: ("Call My Name-TWS", "Call-My-Name"),
}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, "<f4").astype(np.float64)


def analyse(x):
    n, hop = 8192, 2048
    win = np.hanning(n)
    frames = np.lib.stride_tricks.sliding_window_view(x, n)[::hop] * win
    mag = np.abs(np.fft.rfft(frames, axis=1))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    # chroma from spectral peaks 130..2100 Hz (bass and drums left out: they pulled every song to G..A)
    lo, hi = np.searchsorted(freqs, 130), np.searchsorted(freqs, 2100)
    chroma = np.zeros(12)
    for fr in mag[::2]:
        seg = fr[lo:hi]
        if seg.max() <= 0:
            continue
        pk = np.where((seg[1:-1] > seg[:-2]) & (seg[1:-1] >= seg[2:]) & (seg[1:-1] > np.median(seg) * 4))[0] + 1
        if len(pk) == 0:
            continue
        # parabolic peak position for a finer frequency
        a, b, c = np.log(seg[pk - 1] + 1e-12), np.log(seg[pk] + 1e-12), np.log(seg[pk + 1] + 1e-12)
        off = 0.5 * (a - c) / np.where(a - 2 * b + c == 0, -1e-9, a - 2 * b + c)
        f = freqs[lo + pk] + off * (freqs[1] - freqs[0])
        w = np.sqrt(seg[pk] / seg.max())
        semis = 12 * np.log2(f / 261.6256)
        near = np.abs(semis - np.round(semis)) < 0.35
        np.add.at(chroma, (np.round(semis[near]) % 12).astype(int), w[near])
    chroma /= chroma.max()
    best = None
    for mode, prof in (("major", MAJOR), ("minor", MINOR)):
        for r in range(12):
            c = np.corrcoef(chroma, np.roll(prof, r))[0, 1]
            if best is None or c > best[0]:
                best = (c, r, mode)
    power = mag ** 2
    tot = power.sum()
    bass = power[:, freqs < 150].sum() / tot
    centroid = float((power.sum(0) * freqs).sum() / tot)
    # onset envelope (spectral flux) at hop 512 for tempo
    n2, hop2 = 2048, 256
    f2 = np.lib.stride_tricks.sliding_window_view(x, n2)[::hop2] * np.hanning(n2)
    s2 = np.log1p(np.abs(np.fft.rfft(f2, axis=1)))
    flux = np.maximum(np.diff(s2, axis=0), 0).sum(1)
    flux -= flux.mean()
    ac = np.correlate(flux, flux, "full")[len(flux) - 1:]
    fps = SR / hop2
    lags = np.arange(len(ac))
    bpms = 60 * fps / np.maximum(lags, 1)
    ok = (bpms >= 70) & (bpms <= 180)
    lag = lags[ok][np.argmax(ac[ok] * np.exp(-0.5 * (np.log2(bpms[ok] / 120)) ** 2))]
    if 1 <= lag < len(ac) - 1:  # parabolic lag for a finer tempo
        a, b, c = ac[lag - 1], ac[lag], ac[lag + 1]
        lag = lag + 0.5 * (a - c) / (a - 2 * b + c) if a - 2 * b + c != 0 else lag
    bpm = 60 * fps / lag
    return {"key": NAMES[best[1]], "root": best[1], "mode": best[2], "keyConf": round(float(best[0]), 3),
            "bpm": round(float(bpm), 1), "bass": round(float(bass), 3), "centroid": round(centroid), "chroma": [round(float(v), 3) for v in chroma]}


def main():
    out = {}
    files = glob.glob(os.path.join(SRC, "*.mp3"))
    for sid, (title, part) in SONGS.items():
        hit = [f for f in files if part in os.path.basename(f)]
        if not hit:
            print("missing", title)
            continue
        r = analyse(decode(hit[0]))
        r["title"] = title
        out[str(sid)] = r
        print(f"{title:28s} {r['key']:>2} {r['mode']:5s} conf {r['keyConf']:.2f} bpm {r['bpm']:6.1f} bass {r['bass']:.2f} cen {r['centroid']}")
    path = sys.argv[1] if len(sys.argv) > 1 else "D:/Roblox/영상/_work/dance_sfx/songs.json"
    with open(path, "w", encoding="utf8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
