"""Sung stretches of a song for ChoreoMouth (D-1186): YAMNet (MediaPipe audio classifier) on the sound of a video or
mp3, the 'Singing' / 'Speech' / 'Rapping' / 'Vocal music' scores every ~0.5 s, smoothed, gaps under 0.8 s joined,
stretches under 1.2 s dropped. Prints a ClubPlaylist line in song seconds.

python -I vocals.py <video or audio> <offset> [threshold]
  offset = video - song (the choreography's sound alignment, e.g. Catch Catch -0.70); threshold default 0.25
Model: tools/choreo/centercut/models/yamnet.tflite (downloaded with the user's OK, 2026-11-10)."""
import sys, os, subprocess
import numpy as np
from mediapipe.tasks.python import audio as mpa
from mediapipe.tasks.python.components.containers import audio_data as mpad
from mediapipe.tasks.python.core import base_options as mpb

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = next(p for p in (os.path.join(HERE, "centercut", "models", "yamnet.tflite"),
                         r"D:\Roblox\Roblox-FashionSocial\tools\choreo\centercut\models\yamnet.tflite") if os.path.exists(p))
VOICE = {"Singing", "Speech", "Rapping", "Vocal music", "Choir", "Female singing", "Male singing", "Child singing", "Chant", "Humming"}


def main(path, offset, thr):
    sr = 16000
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"], capture_output=True).stdout
    x = np.frombuffer(raw, np.float32)
    opts = mpa.AudioClassifierOptions(base_options=mpb.BaseOptions(model_asset_path=MODEL), max_results=-1,
                                      running_mode=mpa.RunningMode.AUDIO_CLIPS)
    with mpa.AudioClassifier.create_from_options(opts) as clf:
        res = clf.classify(mpad.AudioData.create_from_array(x, sr))
    times, score = [], []
    for r in res:
        cats = r.classifications[0].categories
        v = sum(c.score for c in cats if c.category_name in VOICE)
        times.append(r.timestamp_ms / 1000)
        score.append(min(v, 1))
    times, score = np.array(times), np.array(score)
    if len(score) >= 3:
        score = np.convolve(score, np.ones(3) / 3, mode="same")
    on = score > thr
    spans, start = [], None
    for t, o in zip(times, on):
        if o and start is None:
            start = t
        if not o and start is not None:
            spans.append([start, t])
            start = None
    if start is not None:
        spans.append([start, times[-1] + 0.5])
    joined = []
    for a, b in spans:
        if joined and a - joined[-1][1] < 0.8:
            joined[-1][1] = b
        else:
            joined.append([a, b])
    joined = [[a - offset, b - offset] for a, b in joined if b - a >= 1.2]
    joined = [[max(a, 0), b] for a, b in joined if b > 0]
    total = sum(b - a for a, b in joined)
    print("-- %d stretches, %.0f s sung of %.0f s (threshold %.2f)" % (len(joined), total, times[-1] - offset if len(times) else 0, thr))
    print("vocals = { " + ", ".join("{ %.1f, %.1f }" % (a, b) for a, b in joined) + " },")


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]), float(sys.argv[3]) if len(sys.argv) > 3 else 0.25)
