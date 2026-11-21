"""(D-1876) The Roblox event card thumbnail for the winter attendance event 오후의 첫눈.

16:9, 1920 x 1080: a snowy night (navy to icy blue, warm bokeh lights, falling snow, a snow
ground), three in-game avatars (docs/04_ART/thumbnails/looks/*_trim.png) on the right, and on
the left the event in the game's title font (Bagel Fat One): a "겨울 출석 이벤트" pill, the
title, the dates, and the two limited rewards (the winter frame and the WINTER 2026 title).

    python -I tools/art/event_thumb_winter.py
    -> docs/04_ART/thumbnails/events/winter2026_event_1920x1080.png
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOOKS = os.path.join(ROOT, "docs", "04_ART", "thumbnails", "looks")
FONT = os.path.join(ROOT, "docs", "04_ART", "fonts", "BagelFatOne-Regular.ttf")
JUA = os.path.join(ROOT, "docs", "04_ART", "fonts", "Jua-Regular.ttf")
FRAME = os.path.join(ROOT, "tools", "art", "winter_frame", "winter_2x2.png")
OUT = os.path.join(ROOT, "docs", "04_ART", "thumbnails", "events", "winter2026_event_1920x1080.png")

W, H = 1920, 1080
NAVY = (22, 36, 84)
DEEP = (18, 30, 72)
ICE = (170, 222, 255)
WHITE = (255, 255, 255)
rnd = random.Random(2026)


def font(path, size):
    return ImageFont.truetype(path, size)


def background():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    top, mid, bot = (14, 22, 60), (40, 70, 140), (150, 190, 240)
    for y in range(H):
        t = y / H
        if t < 0.6:
            k = t / 0.6
            c = tuple(round(top[i] + (mid[i] - top[i]) * k) for i in range(3))
        else:
            k = (t - 0.6) / 0.4
            c = tuple(round(mid[i] + (bot[i] - mid[i]) * k) for i in range(3))
        d.line([(0, y), (W, y)], fill=c)
    img = img.convert("RGBA")
    # warm and pink city bokeh
    bokeh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bokeh)
    for _ in range(70):
        x, y = rnd.uniform(0, W), rnd.uniform(H * 0.25, H * 0.78)
        r = rnd.uniform(14, 60)
        col = rnd.choice([(255, 210, 140), (255, 170, 200), (180, 210, 255), (255, 235, 190)])
        bd.ellipse([x - r, y - r, x + r, y + r], fill=col + (rnd.randint(40, 110),))
    img.alpha_composite(bokeh.filter(ImageFilter.GaussianBlur(10)))
    # a soft light behind the avatars
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([1050, 160, 1900, 1020], fill=(200, 230, 255, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    # snow ground: two soft drifts
    ground = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(ground)
    gd.ellipse([-300, 860, 1100, 1400], fill=(235, 244, 255, 255))
    gd.ellipse([700, 830, 2300, 1420], fill=(244, 249, 255, 255))
    img.alpha_composite(ground.filter(ImageFilter.GaussianBlur(4)))
    return img


def snow(img, n, rmin, rmax, blur, alpha):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y, r = rnd.uniform(0, W), rnd.uniform(0, H), rnd.uniform(rmin, rmax)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)) if blur else layer)


def flake(d, cx, cy, r, col, width):
    for i in range(6):
        a = i * math.pi / 3 + 0.26
        ex, ey = cx + math.cos(a) * r, cy + math.sin(a) * r
        d.line([(cx, cy), (ex, ey)], fill=col, width=width)
        for f in (0.5, 0.75):
            bx, by = cx + math.cos(a) * r * f, cy + math.sin(a) * r * f
            for s in (-1, 1):
                b = a + s * math.pi / 4
                L = r * (0.3 if f < 0.6 else 0.2)
                d.line([(bx, by), (bx + math.cos(b) * L, by + math.sin(b) * L)], fill=col, width=width)
    d.ellipse([cx - width, cy - width, cx + width, cy + width], fill=col)


def avatars(img):
    picks = [("clouded_cape_traveler_trim.png", 1290, 1.42), ("blossom_plushie_princess_trim.png", 1530, 1.42),
             ("stray_cat_wanderer_trim.png", 1745, 1.18)]
    feet = 1000
    for name, cx, s in picks:
        a = Image.open(os.path.join(LOOKS, name)).convert("RGBA")
        a = a.resize((round(a.width * s), round(a.height * s)), Image.LANCZOS)
        x, y = round(cx - a.width / 2), feet - a.height
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse([cx - a.width * 0.42, feet - 18, cx + a.width * 0.42, feet + 22], fill=(60, 90, 150, 110))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)))
        # white rim so the dark outfits read on the night
        rim = Image.new("RGBA", a.size, (255, 255, 255, 0))
        rim.putalpha(a.getchannel("A").filter(ImageFilter.MaxFilter(9)).point(lambda v: 200 if v > 40 else 0))
        rim = rim.filter(ImageFilter.GaussianBlur(3))
        img.alpha_composite(rim, (x, y))
        img.alpha_composite(a, (x, y))


def text_block(img, xy, text, f, fill, outline, ow, glow=None, drop=None):
    x, y = xy
    if glow:
        g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(g).text((x, y), text, font=f, fill=glow, stroke_width=ow + 10, stroke_fill=glow)
        img.alpha_composite(g.filter(ImageFilter.GaussianBlur(18)))
    d = ImageDraw.Draw(img)
    if drop:
        d.text((x + 6, y + 9), text, font=f, fill=drop, stroke_width=ow, stroke_fill=drop)
    d.text((x, y), text, font=f, fill=fill, stroke_width=ow, stroke_fill=outline)


def main():
    img = background()
    snow(img, 260, 2, 5, 2, 150)
    avatars(img)
    d = ImageDraw.Draw(img)

    # logo
    text_block(img, (110, 70), "OHU", font(FONT, 92), WHITE, DEEP, 6, glow=(150, 190, 255, 160))
    text_block(img, (318, 108), "오후", font(JUA, 46), WHITE, DEEP, 4)

    # pill: ❄ 겨울 출석 이벤트
    pf = font(JUA, 50)
    label = "겨울 출석 이벤트"
    tw = d.textlength(label, font=pf)
    px0, py0 = 110, 230
    d.rounded_rectangle([px0, py0, px0 + tw + 140, py0 + 86], radius=43, fill=(60, 140, 230), outline=WHITE, width=5)
    flake(d, px0 + 52, py0 + 43, 24, WHITE, 5)
    d.text((px0 + 96, py0 + 43), label, font=pf, fill=WHITE, anchor="lm")

    # title
    text_block(img, (100, 335), "오후의 첫눈", font(FONT, 190), WHITE, (40, 90, 190), 12,
               glow=(140, 200, 255, 200), drop=(20, 40, 110))
    text_block(img, (112, 565), "OHU FIRST SNOW", font(FONT, 58), ICE, DEEP, 5)

    # dates
    df = font(JUA, 58)
    first = "12/6 ~ 12/31"
    text_block(img, (112, 660), first, df, WHITE, DEEP, 5)
    dx = 112 + ImageDraw.Draw(img).textlength(first, font=df) + 34
    ImageDraw.Draw(img).ellipse([dx - 9, 700 - 9, dx + 9, 700 + 9], fill=WHITE, outline=DEEP, width=4)  # (Jua has no ·)
    text_block(img, (dx + 34, 660), "14번 출석하면 완료!", df, WHITE, DEEP, 5)

    # rewards: the frame and the title plate
    fr = Image.open(FRAME).convert("RGBA")
    fh = 240
    fr = fr.resize((round(fr.width * fh / fr.height), fh), Image.LANCZOS)
    card = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rectangle([0, 0, fr.width, fr.height], fill=(225, 238, 255, 255))
    card.putalpha(fr.getchannel("A").point(lambda v: 255 if v > 0 else 0).filter(ImageFilter.MaxFilter(1)))
    holes = Image.new("RGBA", fr.size, (232, 242, 255, 255))
    holes.alpha_composite(fr)
    rot = holes.rotate(-6, expand=True, resample=Image.BICUBIC)
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([132, 790, 132 + rot.width - 20, 790 + rot.height - 30], radius=30, fill=(10, 20, 60, 120))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    img.alpha_composite(rot, (104, 760))
    d = ImageDraw.Draw(img)
    rx = 110 + rot.width + 40
    lf = font(JUA, 44)
    d.text((rx, 800), "7번째  겨울 한정 프레임", font=lf, fill=WHITE, stroke_width=4, stroke_fill=DEEP)
    d.text((rx, 880), "14번째", font=lf, fill=WHITE, stroke_width=4, stroke_fill=DEEP)
    plf = font(FONT, 46)
    ptxt = "WINTER 2026"
    pw = d.textlength(ptxt, font=plf)
    bx = rx + d.textlength("14번째  ", font=lf)
    d.rounded_rectangle([bx, 872, bx + pw + 44, 940], radius=10, fill=(18, 32, 68), outline=(110, 190, 255), width=5)
    d.text((bx + 22, 906), ptxt, font=plf, fill=ICE, anchor="lm")
    d.text((bx + pw + 64, 880), "한정 칭호", font=lf, fill=WHITE, stroke_width=4, stroke_fill=DEEP)

    # big flakes and foreground snow
    fl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fl)
    for (x, y, r) in [(1000, 120, 60), (1180, 70, 34), (1860, 110, 46), (930, 420, 28), (60, 520, 30)]:
        flake(fd, x, y, r, (255, 255, 255, 230), max(3, r // 9))
    img.alpha_composite(fl)
    snow(img, 70, 4, 9, 3, 200)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.convert("RGB").save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
