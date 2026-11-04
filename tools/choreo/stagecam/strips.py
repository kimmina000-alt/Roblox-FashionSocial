"""Film strips with song-time labels. python strips.py video out_dir OFF step name:a-b ..."""
import sys

import cv2
import numpy as np

video, out, OFF, step = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
cap = cv2.VideoCapture(video)
FPS = cap.get(cv2.CAP_PROP_FPS)
for spec in sys.argv[5:]:
    name, rng = spec.split(":")
    a, b = map(float, rng.split("-"))
    cap.set(cv2.CAP_PROP_POS_FRAMES, int((a + OFF) * FPS) - 1)
    fi = int((a + OFF) * FPS) - 1
    want = list(np.arange(a, b + 1e-6, step))
    tiles = []
    while want:
        ok, f = cap.read()
        if not ok:
            break
        t = fi / FPS - OFF
        fi += 1
        if t + 0.5 / FPS >= want[0]:
            im = cv2.resize(f, (224, 126))
            cv2.rectangle(im, (0, 0), (60, 16), (0, 0, 0), -1)
            cv2.putText(im, f"{want[0]:.2f}", (2, 13), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)
            tiles.append(im)
            want.pop(0)
    cols = 8
    while len(tiles) % cols:
        tiles.append(np.zeros_like(tiles[0]))
    rows = [np.hstack(tiles[i:i + cols]) for i in range(0, len(tiles), cols)]
    cv2.imwrite(f"{out}\\strip_{name}.jpg", np.vstack(rows))
    print(name, len(tiles))
