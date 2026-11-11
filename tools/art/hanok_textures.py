"""Hanok facade / stone wall textures for the 한옥 마을 blockout (D-1318).

python tools/art/hanok_textures.py <out_dir>
  hanok_bay_door.png  one bay (칸): posts at the edges, beams, a pair of lattice doors
  hanok_bay_wall.png  one bay: white plaster, a small lattice window, the middle beam
  hanok_stonewall.png 돌담: rounded field stones in light mortar
"""
import random
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 512
WOOD = (122, 80, 50)
WOOD_D = (96, 62, 40)
PLASTER = (238, 234, 222)
PAPER = (226, 212, 180)


def frame(d: ImageDraw.ImageDraw):
    W = H = S
    d.rectangle([0, 0, W, H], fill=PLASTER)
    d.rectangle([0, 0, W, int(H * 0.09)], fill=WOOD)  # 창방
    d.rectangle([0, int(H * 0.15), W, int(H * 0.19)], fill=WOOD)  # 상인방
    d.rectangle([0, int(H * 0.86), W, H], fill=WOOD_D)  # 하인방 + 머름
    d.line([0, int(H * 0.93), W, int(H * 0.93)], fill=WOOD, width=4)
    pw = int(W * 0.065)
    d.rectangle([0, 0, pw, H], fill=WOOD)  # posts (half at each edge; tiles join them)
    d.rectangle([W - pw, 0, W, H], fill=WOOD)


def lattice(d: ImageDraw.ImageDraw, x0, y0, x1, y1, step=14, bar=3):
    d.rectangle([x0, y0, x1, y1], fill=PAPER)
    x = x0 + step
    while x < x1 - 2:
        d.rectangle([x - bar // 2, y0, x + bar // 2, y1], fill=WOOD)
        x += step
    y = y0 + step
    while y < y1 - 2:
        d.rectangle([x0, y - bar // 2, x1, y + bar // 2], fill=WOOD)
        y += step
    fw = 7
    d.rectangle([x0, y0, x1, y0 + fw], fill=WOOD)
    d.rectangle([x0, y1 - fw, x1, y1], fill=WOOD)
    d.rectangle([x0, y0, x0 + fw, y1], fill=WOOD)
    d.rectangle([x1 - fw, y0, x1, y1], fill=WOOD)


def door_tile() -> Image.Image:
    im = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(im)
    frame(d)
    W = H = S
    y0, y1 = int(H * 0.19), int(H * 0.86)
    lattice(d, int(W * 0.15), y0, int(W * 0.5) - 2, y1)
    lattice(d, int(W * 0.5) + 2, y0, int(W * 0.85), y1)
    # the lower panel of each leaf (궁판)
    for x0, x1 in ((int(W * 0.15), int(W * 0.5) - 2), (int(W * 0.5) + 2, int(W * 0.85))):
        d.rectangle([x0, int(H * 0.74), x1, y1], fill=WOOD)
        d.rectangle([x0 + 10, int(H * 0.76), x1 - 10, y1 - 8], outline=WOOD_D, width=3)
    # door rings
    for x in (int(W * 0.5) - 14, int(W * 0.5) + 14):
        d.ellipse([x - 6, int(H * 0.52) - 6, x + 6, int(H * 0.52) + 6], outline=(70, 60, 50), width=3)
    return im


def wall_tile() -> Image.Image:
    im = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(im)
    frame(d)
    W = H = S
    d.rectangle([0, int(H * 0.56), W, int(H * 0.60)], fill=WOOD)  # 중인방
    lattice(d, int(W * 0.34), int(H * 0.27), int(W * 0.66), int(H * 0.52), step=12)
    # a slight plaster grain
    return im.filter(ImageFilter.SMOOTH)


def stone_wall() -> Image.Image:
    rnd = random.Random(1318)
    im = Image.new("RGB", (S, S), (214, 206, 190))
    d = ImageDraw.Draw(im)
    y = -10
    while y < S:
        h = rnd.randint(46, 70)
        x = -rnd.randint(0, 40)
        while x < S:
            w = rnd.randint(56, 96)
            g = rnd.randint(118, 168)
            c = (g, g - rnd.randint(0, 10), g - rnd.randint(4, 18))
            box = [x + 5, y + 5, x + w - 5, y + h - 5]
            d.ellipse(box, fill=c, outline=(96, 92, 86), width=3)
            # wrap so the tile repeats
            if x + w > S:
                d.ellipse([box[0] - S, box[1], box[2] - S, box[3]], fill=c, outline=(96, 92, 86), width=3)
            x += w
        y += h
    return im.filter(ImageFilter.SMOOTH_MORE)


if __name__ == "__main__":
    out = sys.argv[1]
    door_tile().save(f"{out}/hanok_bay_door.png")
    wall_tile().save(f"{out}/hanok_bay_wall.png")
    stone_wall().save(f"{out}/hanok_stonewall.png")
    print("ok")
