"""Song <-> dance video offset, window by window (D-876, CHOREOGRAPHY.md §12).

Usage:
  python align_song_video.py <song_loudness.txt> <video.mp4> [--window 20] [--step 15]

song_loudness.txt: the DUMP output of record_loudness.lua (first line "bin 0.05",
then comma-separated loudness per bin, original song seconds; blanks allowed).
The video's audio is read with ffmpeg (on PATH or FFMPEG env var).

Prints, for windows across the song, the best offsets (video time = song time +
offset) for loudness level and onsets, then a straight-line fit of the clear
windows. With the D-876 clock the offset should be the same everywhere: a
slope means the file speed is not 3 (set `fileSpeed` on the track) or the
video is a different edit (live stage). Set each piece's `at` = its video start
- the offset.
"""
import os
import subprocess
import sys

import numpy as np


def video_envelope(path, step):
    ffmpeg = os.environ.get("FFMPEG", "ffmpeg")
    raw = subprocess.run([ffmpeg, "-v", "error", "-i", path, "-vn", "-ac", "1", "-ar", "8000", "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    a = np.frombuffer(raw, dtype=np.int16).astype(float)
    n = int(8000 * step)
    m = len(a) // n
    return np.sqrt((a[: m * n].reshape(m, n) ** 2).mean(1))


def main():
    args, opts, it = [], {}, iter(sys.argv[1:])
    for x in it:
        if x.startswith("--"):
            opts[x] = next(it)
        else:
            args.append(x)
    window = float(opts.get("--window", 20))
    stride = float(opts.get("--step", 15))
    lines = open(args[0], encoding="utf-8").read().strip().splitlines()
    step = float(lines[0].split()[1])
    vals = lines[1].split(",")
    s = np.array([float(x) if x else np.nan for x in vals])
    idx = np.arange(len(s))
    ok = ~np.isnan(s)
    s = np.interp(idx, idx[ok], s[ok])
    e = video_envelope(args[1], step)
    ts, tv = np.arange(len(s)) * step, np.arange(len(e)) * step

    def level(x):
        return np.log1p(x)

    def onset(x):
        d = np.diff(np.log1p(x), prepend=np.log1p(x[0]))
        d[d < 0] = 0
        return d

    clear = []
    for name, f in (("level", level), ("onset", onset)):
        S, E = f(s), f(e)
        print(name)
        for c in np.arange(window / 2, ts[-1] - window / 2, stride):
            g = np.arange(c - window / 2, c + window / 2, step)
            sg = np.interp(g, ts, S)
            sg = (sg - sg.mean()) / (sg.std() + 1e-9)
            res = []
            for lag in np.arange(-6, 6, step):
                vg = np.interp(g + lag, tv, E)
                vg = (vg - vg.mean()) / (vg.std() + 1e-9)
                res.append(((sg * vg).mean(), lag))
            res.sort(reverse=True)
            best, second = res[0], next(r for r in res if abs(r[1] - res[0][1]) > 0.3)
            sure = best[0] > 0.2 and best[0] - second[0] > 0.03
            if sure:
                clear.append((c, best[1]))
            print(f"  song {c:6.1f}: " + "  ".join(f"{l:+.2f}({r:.2f})" for r, l in res[:3]) + ("" if sure else "   (unclear)"))
    if len(clear) >= 2:
        c, o = np.array(clear).T
        med = np.median(o)
        keep = np.abs(o - med) < 0.5
        k, b = np.polyfit(c[keep], o[keep], 1) if keep.sum() >= 2 else (0.0, med)
        print(f"\noffset (video = song + offset): median {med:+.2f} s; fit {b:+.2f} {k * 100:+.3f} % x song time "
              f"from {keep.sum()} clear windows")
        if abs(k) > 0.0005:
            print("  !! the offset drifts: check the file speed (fileSpeed) or whether the video is another edit")


if __name__ == "__main__":
    main()
