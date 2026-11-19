"""Textures for the 한옥 마을 골목 (D-1910).

python tools/art/hanok_village_textures.py <out_dir>
  hv_slabs.png   alley paving: rectangular granite slabs in rows of random length, dark joints (Bukchon alley, photo 8)
"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

random.seed(1910)


def slabs(S=512):
    img = Image.new("RGB", (S, S), (96, 92, 84))
    d = ImageDraw.Draw(img)
    y = 0
    rows = [64, 56, 72, 60, 68, 52, 70, 70]
    for h in rows:
        x = -random.randint(0, 80)
        while x < S:
            w = random.randint(70, 170)
            g = random.randint(158, 186)
            c = (g + 6, g + 3, g - 6)
            d.rectangle([x + 3, y + 3, x + w - 3, y + h - 3], fill=c)
            for _ in range(900):
                px, py = random.uniform(x + 4, x + w - 4), random.uniform(y + 4, y + h - 4)
                k = random.randint(-22, 14)
                d.point((px, py), fill=(c[0] + k, c[1] + k, c[2] + k))
            x += w
        y += h
    # make it tile vertically: rows sum to 512
    return img.filter(ImageFilter.GaussianBlur(0.6))


if __name__ == "__main__":
    out = sys.argv[1]
    slabs().save(f"{out}/hv_slabs.png")
    print("ok")


def giwa(S=512, n=8):
    """hv_giwa.png: rows of round cover tiles (수키와) over concave tiles, for the lower eave skirt (photo 1)."""
    img = Image.new("RGB", (S, S))
    px = img.load()
    import math
    w = S / n
    for x in range(S):
        u = (x % w) / w  # 0..1 across one rib pair
        if u < 0.42:  # round cover tile: bright centre, dark edges
            t = math.sin(u / 0.42 * math.pi)
            base = 70 + 70 * t
        else:  # concave pan tile: dark trough
            t = math.sin((u - 0.42) / 0.58 * math.pi)
            base = 66 - 18 * t
        for y in range(S):
            seam = 1.0 if (y % 64) > 3 else 0.7  # tile overlap lines
            g = base * seam
            px[x, y] = (int(g), int(g + 3), int(g + 8))
    return img.filter(ImageFilter.GaussianBlur(0.8))


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "giwa":
    giwa().save(f"{sys.argv[1]}/hv_giwa.png")
