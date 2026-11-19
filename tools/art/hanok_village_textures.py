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
