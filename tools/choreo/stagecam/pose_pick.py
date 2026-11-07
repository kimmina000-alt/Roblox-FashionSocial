"""Pick between start-point candidates by the choreography (D-939): frames of
the practice video and of the stage video at the same song moments, one row
per moment: practice | stage at candidate A | stage at candidate B ...

python pose_pick.py <practice.mp4> <practice offset> <stage.mp4> <out.jpg>
                    <song times comma list> <candidate offsets...>
offset = video time - song time.
"""
import sys

import cv2
import numpy as np

prac, poff, stage, out = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4]
times = [float(x) for x in sys.argv[5].split(",")]
cands = [float(x) for x in sys.argv[6:]]


def grab(path, t):
    cap = cv2.VideoCapture(path)
    cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
    ok, f = cap.read()
    cap.release()
    if not ok:
        f = np.zeros((360, 640, 3), np.uint8)
    return cv2.resize(f, (320, 180))


rows = []
for t in times:
    tiles = [grab(prac, t + poff)] + [grab(stage, t + c) for c in cands]
    labels = [f"song {t:.1f} practice"] + [f"stage {c:+.2f}" for c in cands]
    for im, lab in zip(tiles, labels):
        cv2.rectangle(im, (0, 0), (200, 20), (0, 0, 0), -1)
        cv2.putText(im, lab, (3, 15), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)
    rows.append(np.hstack(tiles))
ok, buf = cv2.imencode(".jpg", np.vstack(rows))
buf.tofile(out)
print(out)
