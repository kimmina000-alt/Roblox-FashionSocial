# (D-1435) 회전컵: the user's own drip picture (docs/04_ART/park/teacups_tex/v2/user_drip.png (copied from D:/Roblox/오후/3D 물/teacups_tex/v2), a blue
# drip on white) on the cups. The cup's UV (tools/art/teacups_tex.py) uses the top 0.8 of the image for
# the side (top of the cup = top of the image) and swatches below (inside white, floor grey), so the
# picture is fitted into the top 0.8 and the swatches are kept; the blue is re-tinted per cup.
import numpy as np
from PIL import Image
SRC = "D:/Roblox/오후/3D 물/teacups_tex/v2/"
W = 1024
src = np.asarray(Image.open(SRC + "user_drip.png").convert("RGB").resize((W, int(W * 0.8)), Image.LANCZOS)).astype(float)
# how much of the drip colour each pixel has (0 = white .. 1 = the drip)
base = np.array([90, 176, 228], float)
white = np.array([255, 255, 255], float)
t = np.clip(((white - src) @ (white - base)) / ((white - base) @ (white - base)), 0, 1)[..., None]
COLS = {'green': (70, 150, 95), 'red': (214, 60, 58), 'yellow': (244, 196, 52), 'blue': (88, 176, 228), 'darkgreen': (52, 84, 58)}
for name, col in COLS.items():
    side = (white * (1 - t) + np.array(col, float) * t).astype(np.uint8)
    img = Image.new('RGB', (W, W), (248, 248, 246))
    img.paste(Image.fromarray(side), (0, 0))
    px = img.load()
    for y in range(int(0.86 * W), W):        # the floor swatch (right half of the bottom)
        for x in range(W // 2, W):
            px[x, y] = (214, 220, 228)
    img.save(SRC + f"CupDrip_{name}.png")
print("ok")
