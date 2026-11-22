# (D-2045) Cut the user's Santa UI mock-up (docs/04_ART/ui/santa/mockup.jpg) into game images:
# the album frame and the popup frame off the blurred town (GrabCut inside a hand-drawn band).
#   python matte.py <mockup.jpg> <outdir>
import cv2, numpy as np, sys, os
im = cv2.imread(sys.argv[1]); out = sys.argv[2]; os.makedirs(out, exist_ok=True)
H, W = im.shape[:2]

ALBUM = [  # rough outline, clockwise from the left top
    (20, 232), (26, 212), (60, 196), (95, 190), (97, 160), (112, 125), (127, 97), (145, 118), (160, 150),
    (250, 132), (420, 100), (440, 100), (452, 75), (480, 40), (520, 22), (570, 22), (615, 42), (645, 75), (660, 105),
    (652, 128), (630, 140), (660, 160), (668, 190), (690, 186), (745, 165), (800, 158), (1000, 160), (1025, 190),
    (1037, 235), (1037, 820), (1048, 860), (1040, 895), (1005, 915), (960, 925), (760, 925), (720, 918),
    (360, 920), (300, 925), (60, 928), (20, 915), (10, 885), (12, 845), (22, 815),
]
BGFIX = [(722, 168), (775, 148), (775, 172), (736, 188)]
SPARK = [(632, 40), (660, 28), (692, 55), (680, 84), (650, 72)]
POPUP = [(1072, 240), (1082, 222), (1110, 214), (1480, 214), (1512, 224), (1522, 250), (1522, 860), (1505, 882), (1090, 882), (1070, 860)]

def cut(name, polys, box, band=10):
    poly_mask = np.zeros((H, W), np.uint8)
    for p in polys: cv2.fillPoly(poly_mask, [np.array(p, np.int32)], 255)
    k = np.ones((2 * band + 1, 2 * band + 1), np.uint8)
    outer = cv2.dilate(poly_mask, k); inner = cv2.erode(poly_mask, k)
    gc = np.full((H, W), cv2.GC_BGD, np.uint8)
    gc[outer > 0] = cv2.GC_PR_BGD
    gc[poly_mask > 0] = cv2.GC_PR_FGD
    gc[inner > 0] = cv2.GC_FGD
    if name == 'album': cv2.fillPoly(gc, [np.array(BGFIX, np.int32)], cv2.GC_BGD)
    cv2.grabCut(im, gc, None, np.zeros((1, 65)), np.zeros((1, 65)), 6, cv2.GC_INIT_WITH_MASK)
    fg = np.where((gc == 1) | (gc == 3), 255, 0).astype(np.uint8)
    # fill holes, keep pieces touching the inner core, soften the edge a little
    n, lab = cv2.connectedComponents(fg)
    keep = np.unique(lab[(inner > 0) & (fg > 0)]); keep = keep[keep > 0]
    fg = np.isin(lab, keep).astype(np.uint8) * 255
    inv = 255 - fg; ff = inv.copy(); cv2.floodFill(ff, None, (0, 0), 0)
    fg = fg | ff
    a = cv2.GaussianBlur(fg, (3, 3), 0)
    x0, y0, x1, y1 = box
    rgba = cv2.cvtColor(im, cv2.COLOR_BGR2BGRA); rgba[:, :, 3] = a
    cv2.imwrite(os.path.join(out, name + '_cut.png'), rgba[y0:y1, x0:x1])
    return rgba[y0:y1, x0:x1]

cut('album', [ALBUM, SPARK], (4, 14, 1056, 934))
cut('popup', [POPUP], (1064, 206, 1530, 892), band=8)
