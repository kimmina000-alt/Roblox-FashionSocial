"""한옥 마을 담장 face texture (D-1328, user photos 2026-11-12: square grey stone
blocks in white mortar, a white plaster band with two rows of dark bricks under the
giwa coping).

python tools/art/hanok_doldam_texture.py <out.png>
One tile = 9.2 studs wide (4 blocks) x the whole wall face (13.8 studs, below the coping).
"""
import random
import sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 512, 768
MORTAR = (232, 230, 222)
PLASTER = (238, 236, 228)
BRICK = (58, 56, 58)
random.seed(1328)

img = Image.new("RGB", (W, H), PLASTER)
d = ImageDraw.Draw(img)

# bottom 64 %: square-cut granite blocks, 6 rows x 4 across, stack bond like the photo
stone_top = int(H * 0.36)
rows, cols = 6, 4
gap = 7
rh = (H - stone_top) / rows
cw = W / cols
d.rectangle([0, stone_top, W, H], fill=MORTAR)
for r in range(rows):
    for c in range(cols):
        x0 = int(c * cw + gap / 2)
        x1 = int((c + 1) * cw - gap / 2)
        y0 = int(stone_top + r * rh + gap / 2)
        y1 = int(stone_top + (r + 1) * rh - gap / 2)
        g = random.randint(150, 182)
        base = (g, g + 1, g + 4)
        d.rectangle([x0, y0, x1, y1], fill=base)
        # speckled granite + a lighter top edge
        for _ in range(260):
            px, py = random.randint(x0, x1), random.randint(y0, y1)
            k = random.randint(-22, 22)
            d.point((px, py), fill=(base[0] + k, base[1] + k, base[2] + k))
        d.line([x0, y0, x1, y0], fill=(g + 18, g + 19, g + 22), width=2)
        d.line([x0, y1, x1, y1], fill=(g - 22, g - 21, g - 18), width=2)

# upper band: white plaster with two courses of dark long bricks (전돌)
def brick_course(y0, y1, offset):
    bw = W / 3
    x = -offset
    while x < W:
        d.rectangle([int(x + 3), y0, int(x + bw - 3), y1], fill=BRICK)
        x += bw

brick_course(int(H * 0.10), int(H * 0.155), 0)
brick_course(int(H * 0.20), int(H * 0.255), W / 6)
# thin dark line where the stone meets the plaster
d.rectangle([0, stone_top - 6, W, stone_top - 2], fill=(150, 148, 146))

img = img.filter(ImageFilter.GaussianBlur(0.6))
img.save(sys.argv[1] if len(sys.argv) > 1 else "hanok_doldam.png")
