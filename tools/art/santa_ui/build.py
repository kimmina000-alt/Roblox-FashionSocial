# (D-2045) Game images from the user's Santa UI mock-up (run matte.py first):
#   album_frame.png  the album with the card area see-through (the cards are drawn under it, the trees' tips stay
#                    on top), today's hint and the count wiped
#   card.png / card_today.png  one card (green date tag) / today's card (red tag, pink edge, ! marks), wiped
#   popup_frame.png  the found popup with the Santa and its name wiped (the glow filled back along its rays)
#   python build.py <mockup.jpg> <dir with album_cut.png / popup_cut.png> <outdir>
import cv2, numpy as np, sys, os
src = cv2.imread(sys.argv[1]); d = sys.argv[2]; out = sys.argv[3]; os.makedirs(out, exist_ok=True)
AX, AY = 4, 14       # album_cut origin in the mock-up
PX, PY = 1064, 182   # popup_cut origin

def inpaint_text(img, rect, pred, grow=3, r=5):
    x0, y0, x1, y1 = rect
    roi = img[y0:y1, x0:x1, :3]
    m = pred(roi.astype(int)).astype(np.uint8) * 255
    m = cv2.dilate(m, np.ones((2 * grow + 1, 2 * grow + 1), np.uint8))
    img[y0:y1, x0:x1, :3] = cv2.inpaint(np.ascontiguousarray(roi), m, r, cv2.INPAINT_TELEA)

def not_bg(roi):  # text: darker or more coloured than the pale panel
    b, g, r = roi[..., 0], roi[..., 1], roi[..., 2]
    return (np.minimum(np.minimum(r, g), b) < 200) | ((np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)) > 45)

# ---- album
a = cv2.imread(os.path.join(d, 'album_cut.png'), cv2.IMREAD_UNCHANGED)
def A(x, y): return x - AX, y - AY
x0, y0 = A(226, 300); x1, y1 = A(732, 334)
inpaint_text(a, (x0, y0, x1, y1), not_bg, 3, 6)                      # hint line
x0, y0 = A(796, 252); x1, y1 = A(910, 302)
inpaint_text(a, (x0, y0, x1, y1), not_bg, 3, 6)                      # "0 / 20"
# card area see-through, but the trees' green tips stay
cx0, cy0 = A(46, 343); cx1, cy1 = A(1015, 808)
hole = np.zeros(a.shape[:2], np.uint8)
cv2.rectangle(hole, (cx0 + 12, cy0), (cx1 - 12, cy1), 255, -1)
cv2.rectangle(hole, (cx0, cy0 + 12), (cx1, cy1 - 12), 255, -1)
for cx, cy in ((cx0 + 12, cy0 + 12), (cx1 - 12, cy0 + 12), (cx0 + 12, cy1 - 12), (cx1 - 12, cy1 - 12)):
    cv2.circle(hole, (cx, cy), 12, 255, -1)
c = a[..., :3].astype(int); b, g, r = c[..., 0], c[..., 1], c[..., 2]
tree = ((g > r + 25) & (g > b) & (g > 60)).astype(np.uint8) * 255
tree = cv2.morphologyEx(tree, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
n, lab, st, _ = cv2.connectedComponentsWithStats(tree)
big = np.zeros_like(tree)
for i in range(1, n):
    if st[i, 4] > 300: big[lab == i] = 255                         # the two trees (not the date tags: those go)
big = cv2.dilate(big, np.ones((3, 3), np.uint8))
lowzone = np.zeros_like(tree); lowzone[A(0, 750)[1]:, :] = 255      # only near the bottom corners
keep = cv2.bitwise_and(big, lowzone)
cut = cv2.bitwise_and(hole, cv2.bitwise_not(keep))
cut = cv2.GaussianBlur(cut, (3, 3), 0)
a[..., 3] = np.minimum(a[..., 3], 255 - cut)
cv2.imwrite(os.path.join(out, 'album_frame.png'), a)
print('album', a.shape[1], a.shape[0], 'hole', cx0, cy0, cx1, cy1)

# ---- cards
def card(rect, body, extra=None, name='card'):
    x0, y0, x1, y1 = rect
    img = src[y0:y1, x0:x1].copy()
    al = np.zeros(img.shape[:2], np.uint8)
    bx0, by0, bx1, by1 = [v - o for v, o in zip(body, (x0, y0, x0, y0))]
    rr = 13
    cv2.rectangle(al, (bx0 + rr, by0), (bx1 - rr, by1), 255, -1); cv2.rectangle(al, (bx0, by0 + rr), (bx1, by1 - rr), 255, -1)
    for cx, cy in ((bx0 + rr, by0 + rr), (bx1 - rr, by0 + rr), (bx0 + rr, by1 - rr), (bx1 - rr, by1 - rr)):
        cv2.circle(al, (cx, cy), rr, 255, -1)
    if extra is not None: al = cv2.bitwise_or(al, extra(img))
    al = cv2.GaussianBlur(al, (3, 3), 0)
    return img, al
def wipe(img, rect, pred, grow=2, r=4):
    inpaint_text(img, rect, pred, grow, r)
white = lambda roi: (roi[..., 0] > 200) & (roi[..., 1] > 200) & (roi[..., 2] > 200)
# normal card: 12/24 (body 857..933 x 591..806)
img, al = card((854, 588, 937, 810), (856, 590, 934, 807))
wipe(img, (12, 8, 70, 36), white, 2, 4)                              # date text
wipe(img, (14, 80, 66, 140), not_bg, 3, 6)                           # the ?
cv2.imwrite(os.path.join(out, 'card.png'), np.dstack([img, al]))
# today's card: 12/23 (body 752..851 x 590..806) + the red ! marks
def marks(img):
    c = img.astype(int); b, g, r = c[..., 0], c[..., 1], c[..., 2]
    m = ((r > 170) & (g < 120)).astype(np.uint8) * 255
    m[28:, :] = 0
    return cv2.dilate(m, np.ones((3, 3), np.uint8))
img, al = card((748, 560, 866, 810), (751, 589, 852, 807), marks)
wipe(img, (14, 36, 92, 66), white, 2, 4)                             # date text
wipe(img, (8, 72, 96, 238), lambda roi: (np.minimum(np.minimum(roi[..., 0], roi[..., 1]), roi[..., 2]) < 215), 3, 7)
cv2.imwrite(os.path.join(out, 'card_today.png'), np.dstack([img, al]))

# ---- popup
p = cv2.imread(os.path.join(d, 'popup_cut.png'), cv2.IMREAD_UNCHANGED)
# dark town bits left between the snow cap and the frame's top corners
top = p[:90].astype(int); tb, tg, tr = top[..., 0], top[..., 1], top[..., 2]
dark = (np.maximum(np.maximum(tr, tg), tb) < 190) & (tb > tr - 15)
dark[:, 60:400] = False                                             # (only by the corners: the confetti stays)
dark = cv2.dilate(dark.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
p[:90, :, 3][dark] = 0
def P(x, y): return x - PX, y - PY
poly = [(1210, 312), (1250, 342), (1350, 342), (1392, 312), (1396, 400), (1410, 480), (1406, 600), (1384, 638), (1212, 638), (1190, 600), (1186, 480), (1200, 400)]
m = np.zeros(p.shape[:2], np.uint8); cv2.fillPoly(m, [np.array([P(*q) for q in poly], np.int32)], 255)
cx, cy = P(1300, 470)
ys, xs = np.where(m > 0)
rgb = p[..., :3].copy()
dx, dy = xs - cx, ys - cy; L = np.maximum(np.hypot(dx, dy), 1.0)
ux, uy = dx / L, dy / L
ux[(dx == 0) & (dy == 0)] = 1.0
t = L.copy(); live = np.ones(len(xs), bool)
for _ in range(400):                                               # march out along each ray to the hole's edge
    qx = np.clip(np.round(cx + ux * t).astype(int), 0, m.shape[1] - 1); qy = np.clip(np.round(cy + uy * t).astype(int), 0, m.shape[0] - 1)
    live &= m[qy, qx] > 0
    if not live.any(): break
    t[live] += 1
t += 4
qx = np.clip(np.round(cx + ux * t).astype(int), 0, m.shape[1] - 1); qy = np.clip(np.round(cy + uy * t).astype(int), 0, m.shape[0] - 1)
rgb[ys, xs] = p[qy, qx, :3]
blur = cv2.GaussianBlur(rgb, (9, 9), 0)
mm = cv2.GaussianBlur(m, (15, 15), 0)[..., None] / 255.0
p[..., :3] = (blur * mm + p[..., :3] * (1 - mm)).astype(np.uint8)
x0, y0 = P(1130, 650); x1, y1 = P(1472, 712)                         # the name line (with a margin to fill from)
inpaint_text(p, (x0, y0, x1, y1), lambda roi: np.pad(np.ones((roi.shape[0] - 16, roi.shape[1] - 16), bool), 8), 0, 8)
cv2.imwrite(os.path.join(out, 'popup_frame.png'), p)
print('popup', p.shape[1], p.shape[0])
