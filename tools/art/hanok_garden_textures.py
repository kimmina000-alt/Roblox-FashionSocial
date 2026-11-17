"""Textures for the 한옥 연못 정원 (D-1741).

python tools/art/hanok_garden_textures.py <out_dir>
  hg_flagstone.png  irregular flat paving stones (crazy paving), seamless, light joints
  hg_books.png      a shelf row of book spines (one shelf height)
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

random.seed(1741)


def flagstone(S=512, n=26):
    pts = [(random.uniform(0, S), random.uniform(0, S)) for _ in range(n)]
    cols = []
    for _ in pts:
        g = random.randint(170, 206)
        cols.append((g + 8, g + 3, g - 10))
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            best = [1e18, 1e18]
            bi = 0
            for i, (ax, ay) in enumerate(pts):
                dx = min(abs(x - ax), S - abs(x - ax))
                dy = min(abs(y - ay), S - abs(y - ay))
                d = dx * dx + dy * dy
                if d < best[0]:
                    best = [d, best[0]]
                    bi = i
                elif d < best[1]:
                    best[1] = d
            edge = best[1] ** 0.5 - best[0] ** 0.5
            if edge < 6:
                px[x, y] = (118, 114, 100)
            else:
                c = cols[bi]
                n_ = random.randint(-6, 6)
                shade = min(1.0, edge / 30) * 6
                px[x, y] = (int(c[0] + n_ + shade), int(c[1] + n_ + shade), int(c[2] + n_ + shade))
    return img.filter(ImageFilter.GaussianBlur(0.7))


def books(W=1024, H=256):
    img = Image.new("RGB", (W, H), (60, 44, 30))
    d = ImageDraw.Draw(img)
    pal = [(232, 226, 210), (196, 170, 130), (120, 90, 64), (70, 84, 96), (160, 60, 50), (210, 196, 160),
           (90, 110, 80), (40, 40, 44), (226, 208, 170), (150, 130, 110)]
    x = 4
    while x < W - 10:
        w = random.randint(14, 34)
        h = random.randint(int(H * 0.62), int(H * 0.95))
        c = random.choice(pal)
        if random.random() < 0.12:  # a gap or a leaning stack
            x += random.randint(20, 50)
            continue
        d.rectangle([x, H - h, x + w, H], fill=c)
        d.line([x + w, H - h, x + w, H], fill=(30, 24, 18), width=2)
        for yy in (H - h + 18, H - 22):
            d.line([x + 3, yy, x + w - 3, yy], fill=tuple(max(0, v - 50) for v in c), width=2)
        x += w + 1
    return img


if __name__ == "__main__":
    out = sys.argv[1]
    flagstone().save(f"{out}/hg_flagstone.png")
    books().save(f"{out}/hg_books.png")
    print("ok")
