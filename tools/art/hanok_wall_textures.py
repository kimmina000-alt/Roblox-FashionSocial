"""Textures for the 한옥 wall kit (D-1740).

python tools/art/hanok_wall_textures.py <out_dir>
  hw_pine.png      pine grain with knots (MaterialVariant colour map for posts / beams)
  hw_plaster.png   white lime plaster, faint trowel marks (MaterialVariant colour map)
  hw_ttisal.png    띠살 door leaf: dense vertical bars, bands of horizontal bars, on hanji
  hw_jeongja.png   정자살 window: square grid on hanji
  hw_bitsal.png    빗살 (diamond) lattice on hanji
hw_ttisal is one leaf (fit to the pane); hw_jeongja / hw_bitsal tile (4 cells a tile).
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

random.seed(1740)
PAPER = (238, 230, 208)
BAR = (196, 142, 84)
BAR_D = (160, 108, 60)


def pine(size=1024):
    w = h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    knots = [(random.uniform(0, w), random.uniform(0, h), random.uniform(14, 30)) for _ in range(3)]
    # grain runs along y (Roblox maps the texture along the part's length when U/V fit)
    phase = [random.uniform(0, 6.28) for _ in range(4)]
    for x in range(w):
        for y in range(h):
            d = 0.0
            for kx, ky, kr in knots:
                dx, dy = (x - kx), (y - ky) * 0.35
                r2 = dx * dx + dy * dy
                d += kr * kr * 2.2 / (r2 + kr * kr) * (1 if dx >= 0 else -1)
            u = x + d * 6 + 3 * math.sin(y / 260 + phase[0]) + 1.2 * math.sin(y / 61 + phase[1])
            u = u + 22 * math.sin(u / 83 + phase[3]) + 9 * math.sin(u / 29)
            ring = (math.sin(u / 9.5) + 1) / 2
            ring = ring ** 5
            fine = (math.sin(u / 1.7 + phase[2]) + 1) / 2 * 0.25
            t = ring * 0.75 + fine
            base = (226, 178, 116)
            dark = (186, 122, 62)
            c = [int(base[i] * (1 - t) + dark[i] * t) for i in range(3)]
            px[x, y] = tuple(c)
    d = ImageDraw.Draw(img)
    for kx, ky, kr in knots:
        for r in range(int(kr), 0, -1):
            f = r / kr
            col = (int(150 + 60 * f), int(90 + 50 * f), int(45 + 35 * f))
            d.ellipse([kx - r * 0.7, ky - r, kx + r * 0.7, ky + r], fill=col)
    return img.filter(ImageFilter.GaussianBlur(0.8))


def plaster(size=512):
    img = Image.new("RGB", (size, size), (242, 239, 230))
    d = ImageDraw.Draw(img)
    for _ in range(900):
        x, y = random.uniform(0, size), random.uniform(0, size)
        r = random.uniform(8, 40)
        g = random.randint(-7, 5)
        d.ellipse([x - r, y - r * 0.5, x + r, y + r * 0.5], fill=(240 + g, 237 + g, 228 + g))
    return img.filter(ImageFilter.GaussianBlur(6))


def paper(w, h):
    img = Image.new("RGB", (w, h), PAPER)
    d = ImageDraw.Draw(img)
    for _ in range(600):
        x, y = random.uniform(0, w), random.uniform(0, h)
        d.line([x, y, x + random.uniform(-6, 6), y + random.uniform(-6, 6)], fill=(228, 218, 192), width=1)
    return img


def bar(d, box):
    d.rectangle(box, fill=BAR)
    x0, y0, x1, y1 = box
    if x1 - x0 > y1 - y0:
        d.line([x0, y1, x1, y1], fill=BAR_D, width=1)
    else:
        d.line([x1, y0, x1, y1], fill=BAR_D, width=1)


def ttisal(w=256, h=768):
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    n, b = 13, 7
    for i in range(1, n):
        x = i * w / n
        bar(d, [x - b / 2, 0, x + b / 2, h])
    for yc in (0.12, 0.5, 0.88):
        for k in (-2, -1, 0, 1, 2):
            y = yc * h + k * 13
            bar(d, [0, y - b / 2, w, y + b / 2])
    return img


def jeongja(w=256, h=256, n=4, b=15):
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    # bars on the tile edges too (half at each side), so tiles repeat seamlessly
    for i in range(0, n + 1):
        x = i * w / n
        bar(d, [x - b / 2, 0, x + b / 2, h])
        y = i * h / n
        bar(d, [0, y - b / 2, w, y + b / 2])
    return img


def bitsal(w=256, h=256, n=4, b=14):
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    s = w / n
    for i in range(-n, 2 * n + 1):
        x = i * s
        d.line([x, 0, x + h, h], fill=BAR, width=b)
        d.line([x, 0, x - h, h], fill=BAR, width=b)
    return img


if __name__ == "__main__":
    out = sys.argv[1]
    pine().save(f"{out}/hw_pine.png")
    plaster().save(f"{out}/hw_plaster.png")
    ttisal().save(f"{out}/hw_ttisal.png")
    jeongja().save(f"{out}/hw_jeongja.png")
    bitsal().save(f"{out}/hw_bitsal.png")
    print("ok")
