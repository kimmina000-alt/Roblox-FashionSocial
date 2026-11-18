"""Textures for the 한옥 카페 (D-1746).

python tools/art/hanok_cafe_textures.py <out_dir>
  hc_rug_red.png / hc_rug_kilim.png  Persian-style red rug and a kilim (geometric) rug, our own patterns
  hc_art_1..3.png                    framed prints: simple abstract / landscape compositions (our own)
  hc_records.png                     a shelf row of vinyl record spines
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

random.seed(1746)


def rug_red(W=512, H=768):
    img = Image.new("RGB", (W, H), (150, 40, 38))
    d = ImageDraw.Draw(img)
    navy, cream, gold, dark = (36, 44, 70), (232, 214, 180), (210, 160, 80), (100, 24, 26)
    for i, c in enumerate([navy, cream, dark, gold, navy]):
        m = 10 + i * 14
        d.rectangle([m, m, W - m, H - m], outline=c, width=7)
    cx, cy = W / 2, H / 2
    for r, c in [(170, navy), (140, cream), (110, dark), (80, gold), (45, navy)]:
        d.polygon([(cx, cy - r * 1.4), (cx + r, cy), (cx, cy + r * 1.4), (cx - r, cy)], fill=c)
    for _ in range(260):
        x, y = random.uniform(90, W - 90), random.uniform(90, H - 90)
        s = random.uniform(3, 7)
        d.ellipse([x - s, y - s, x + s, y + s], fill=random.choice([cream, gold, navy]))
    for k in range(4):
        x = 95 if k % 2 == 0 else W - 95
        y = 140 if k < 2 else H - 140
        d.polygon([(x, y - 40), (x + 30, y), (x, y + 40), (x - 30, y)], fill=navy)
    return img.filter(ImageFilter.GaussianBlur(0.8))


def rug_kilim(W=512, H=768):
    img = Image.new("RGB", (W, H), (214, 196, 168))
    d = ImageDraw.Draw(img)
    cols = [(170, 70, 50), (60, 70, 80), (200, 150, 70), (120, 60, 50)]
    for row in range(0, H, 96):
        c = cols[(row // 96) % 4]
        d.rectangle([0, row + 40, W, row + 52], fill=c)
        for x in range(0, W, 64):
            d.polygon([(x + 32, row + 6), (x + 58, row + 32), (x + 32, row + 58), (x + 6, row + 32)], outline=c, width=6)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def art(n, W=384, H=512):
    pal = [[(236, 226, 206), (196, 90, 60), (40, 60, 70), (210, 170, 90)],
           [(220, 230, 226), (60, 110, 120), (230, 180, 130), (30, 40, 50)],
           [(240, 236, 228), (150, 170, 120), (80, 90, 60), (200, 120, 90)]][n]
    img = Image.new("RGB", (W, H), pal[0])
    d = ImageDraw.Draw(img)
    if n == 0:
        d.ellipse([90, 120, 290, 320], fill=pal[1])
        d.rectangle([0, 330, W, H], fill=pal[2])
        d.rectangle([40, 360, 200, 380], fill=pal[3])
    elif n == 1:
        for i in range(6):
            y = 120 + i * 50
            d.arc([-100, y, W + 100, y + 300], 200, 340, fill=pal[1 + i % 3], width=14)
    else:
        d.polygon([(0, H), (140, 220), (260, 360), (W, 180), (W, H)], fill=pal[2])
        d.polygon([(0, H), (120, 330), (230, 420), (W, 300), (W, H)], fill=pal[1])
        d.ellipse([260, 60, 330, 130], fill=pal[3])
    img = img.resize((W - 48, H - 48))
    framed = Image.new("RGB", (W, H), (34, 30, 28))
    framed.paste(Image.new("RGB", (W - 24, H - 24), (246, 244, 238)), (12, 12))
    framed.paste(img.resize((W - 64, H - 64)), (32, 32))
    return framed


def records(W=1024, H=256):
    img = Image.new("RGB", (W, H), (40, 32, 26))
    d = ImageDraw.Draw(img)
    x = 2
    pal = [(230, 225, 210), (30, 30, 34), (180, 60, 50), (60, 90, 120), (220, 180, 80), (90, 120, 80), (200, 200, 200), (120, 70, 110)]
    while x < W:
        w = random.randint(5, 12)
        c = random.choice(pal)
        d.rectangle([x, 8, x + w, H], fill=c)
        d.line([x + w, 8, x + w, H], fill=(20, 18, 16), width=1)
        x += w + 1
    return img


if __name__ == "__main__":
    out = sys.argv[1]
    rug_red().save(f"{out}/hc_rug_red.png")
    rug_kilim().save(f"{out}/hc_rug_kilim.png")
    for i in range(3):
        art(i).save(f"{out}/hc_art_{i + 1}.png")
    records().save(f"{out}/hc_records.png")
    print("ok")


def sticks(S=512, n=170):
    """hc_sticks.png: thin branches side by side on transparent (pergola roof, photo 5)."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(n):
        y = (i + random.uniform(-0.4, 0.4)) * S / n * 1.0
        w = random.choice([2, 3, 3, 4])
        c = random.choice([(150, 112, 74), (124, 90, 58), (170, 132, 92), (102, 76, 52)])
        pts = []
        for k in range(0, S + 64, 64):
            pts.append((k, y + random.uniform(-2.5, 2.5)))
        d.line(pts, fill=c + (255,), width=w)
        if random.random() < 0.25:
            x0 = random.uniform(0, S)
            d.line([(x0, y), (x0 + random.uniform(20, 60), y + random.uniform(-14, 14))], fill=c + (255,), width=2)
    return img


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "sticks":
    sticks().save(f"{sys.argv[1]}/hc_sticks.png")
