"""Side by side: stage video frame | game capture, one row per moment.
python compare.py video OFF out.jpg t1=game1.jpg t2=game2.jpg ..."""
import sys

import cv2
import numpy as np

video, OFF, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
cap = cv2.VideoCapture(video)
FPS = cap.get(cv2.CAP_PROP_FPS)
rows = []
for spec in sys.argv[4:]:
    t, path = spec.split("=", 1)
    t = float(t)
    cap.set(cv2.CAP_PROP_POS_FRAMES, int(round((t + OFF) * FPS)))
    ok, f = cap.read()
    a = cv2.resize(f, (560, 315))
    g = cv2.imdecode(np.fromfile(path, np.uint8), cv2.IMREAD_COLOR)
    b = cv2.resize(g, (int(g.shape[1] * 315 / g.shape[0]), 315))
    row = np.hstack([a, np.full((315, 6, 3), 255, np.uint8), b])
    cv2.rectangle(row, (0, 0), (190, 24), (0, 0, 0), -1)
    cv2.putText(row, f"song {t:.2f}s  stage | game", (4, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    rows.append(row)
w = max(r.shape[1] for r in rows)
rows = [np.hstack([r, np.zeros((315, w - r.shape[1], 3), np.uint8)]) for r in rows]
ok, buf = cv2.imencode(".jpg", np.vstack([np.vstack([r, np.full((6, w, 3), 255, np.uint8)]) for r in rows]), [cv2.IMWRITE_JPEG_QUALITY, 82])
buf.tofile(out)
print("ok", out)
