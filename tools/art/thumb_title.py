"""Thumbnail titles in the game's title font (D-863 Bagel Fat One, D-864).

The GPT thumbnails come with their own baked-in lettering. This script softens
each lettering block away (a heavy blur, feathered into the picture) and draws
the words again in Bagel Fat One: thick letters (a stroke in the letters' own
colour, user: "엄청 두껍게", kept thin enough that the O keeps its hole), a dark
purple outline, a short 3D drop and a soft glow, the way the GPT titles look.

    python -I tools/art/thumb_title.py            # every job in JOBS
    python -I tools/art/thumb_title.py d_billboard_couple

Sources: docs/04_ART/thumbnails/gpt_1104/<name>.*; results: .../gpt_1104/out/<name>.png
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "docs", "04_ART", "thumbnails", "gpt_1104")
OUT = os.path.join(SRC, "out")
FONT = os.path.join(ROOT, "docs", "04_ART", "fonts", "BagelFatOne-Regular.ttf")

WHITE = (255, 255, 255)
PINK = (255, 205, 232)
LILAC = (236, 220, 255)
DEEP = (78, 30, 150)  # outline
DROP = (46, 14, 96)  # 3D drop under the outline
GLOW = (196, 120, 255)


def font(size):
    return ImageFont.truetype(FONT, size)


def erase(img, box, feather=40, radius=55, passes=3):
    """Blur the lettering in box away, fading into the picture at the edges."""
    x0, y0, x1, y1 = box
    pad = radius * 2
    cx0, cy0 = max(0, x0 - pad), max(0, y0 - pad)
    cx1, cy1 = min(img.width, x1 + pad), min(img.height, y1 + pad)
    crop = img.crop((cx0, cy0, cx1, cy1))
    soft = crop
    for _ in range(passes):
        soft = soft.filter(ImageFilter.GaussianBlur(radius))
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((x0 - cx0, y0 - cy0, x1 - cx0, y1 - cy0), radius=feather, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather / 2))
    crop.paste(soft, (0, 0), mask)
    img.paste(crop, (cx0, cy0))


def fill_flat(img, box, ring=10, feather=10):
    """Paint the lettering inside a button over with the button's own colour
    (the average of a ring just inside the box), soft at the edges."""
    x0, y0, x1, y1 = box
    crop = img.crop(box).convert("RGB")
    w, h = crop.size
    px = [crop.getpixel((x, y)) for x in range(0, w, 3) for y in (min(ring, h - 1), max(0, h - ring - 1))]
    color = tuple(sorted(c[i] for c in px)[len(px) // 2] for i in range(3))
    flat = Image.new("RGBA", img.size, color + (0,))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=min(w, h) // 2, fill=255)
    flat.putalpha(mask.filter(ImageFilter.GaussianBlur(feather)))
    img.alpha_composite(flat)


def text_mask(text, size, stroke, canvas, tracking=0.0):
    """`tracking`: extra room between the letters, in font sizes (D-865, user:
    "O H U 알파벳 사이 간격 둬")."""
    m = Image.new("L", canvas, 0)
    f = font(size)
    d = ImageDraw.Draw(m)
    bbox = d.textbbox((0, 0), text, font=f, stroke_width=stroke)
    h = bbox[3] - bbox[1]
    gap = tracking * size
    w = bbox[2] - bbox[0] + gap * (len(text) - 1)
    x = (canvas[0] - w) / 2 - bbox[0]
    y = (canvas[1] - h) / 2 - bbox[1]
    if not gap:
        d.text((x, y), text, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
        return m
    for ch in text:
        d.text((x, y), ch, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
        x += f.getlength(ch) + gap
    return m


def gradient(canvas, top, bottom):
    g = Image.new("RGB", canvas)
    d = ImageDraw.Draw(g)
    for y in range(canvas[1]):
        t = y / max(1, canvas[1] - 1)
        d.line((0, y, canvas[0], y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g


def title(img, text, center, size, angle=0.0, thick=0.035, outline=0.08, top=WHITE, bottom=PINK,
          edge=DEEP, glow=GLOW, drop=0.06, tracking=0.0):
    """Draw one line of text centred on `center` (x, y), `size` px font."""
    t, o = max(1, int(size * thick)), max(2, int(size * outline))
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    bb = probe.textbbox((0, 0), text, font=font(size), stroke_width=t + o)
    canvas = (int(bb[2] - bb[0] + size + tracking * size * (len(text) - 1)), bb[3] - bb[1] + size)
    fill_m = text_mask(text, size, t, canvas, tracking)
    edge_m = text_mask(text, size, t + o, canvas, tracking)
    glow_m = text_mask(text, size, t + o + int(size * 0.06), canvas, tracking).filter(ImageFilter.GaussianBlur(size * 0.14))

    layer = Image.new("RGBA", canvas, (0, 0, 0, 0))
    glow_l = Image.new("RGBA", canvas, glow + (0,))
    glow_l.putalpha(glow_m.point(lambda v: int(v * 0.8)))
    layer = Image.alpha_composite(layer, glow_l)
    dy = max(1, int(size * drop))
    drop_l = Image.new("RGBA", canvas, DROP + (0,))
    drop_l.putalpha(ImageChops.offset(edge_m, 0, dy))
    layer = Image.alpha_composite(layer, drop_l)
    edge_l = Image.new("RGBA", canvas, edge + (0,))
    edge_l.putalpha(edge_m)
    layer = Image.alpha_composite(layer, edge_l)
    fill_l = gradient(canvas, top, bottom).convert("RGBA")
    fill_l.putalpha(fill_m)
    layer = Image.alpha_composite(layer, fill_l)
    # a glossy band across the upper part of the letters
    shine = Image.new("L", canvas, 0)
    ImageDraw.Draw(shine).rectangle((0, 0, canvas[0], canvas[1] * 0.45), fill=60)
    shine = ImageChops.multiply(shine, fill_m)
    shine_l = Image.new("RGBA", canvas, WHITE + (0,))
    shine_l.putalpha(shine)
    layer = Image.alpha_composite(layer, shine_l)

    if angle:
        layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    x, y = center
    img.alpha_composite(layer, (int(x - layer.width / 2), int(y - layer.height / 2)))


def play_label(img, center, size, angle=0.0):
    """▶ 지금 바로 플레이! on the picture's own button (the font has no ▶: drawn)."""
    text = "지금 바로 플레이!"
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    bb = probe.textbbox((0, 0), text, font=font(size))
    tw = bb[2] - bb[0]
    tri = size * 0.75
    layer = Image.new("RGBA", (int(tw + tri * 2 + size * 2), int(size * 3)), (0, 0, 0, 0))
    cx, cy = layer.width / 2, layer.height / 2
    title(layer, text, (cx + tri * 0.6, cy), size, thick=0.03, outline=0.09, top=WHITE, bottom=WHITE,
          edge=(110, 30, 150), glow=(255, 170, 240), drop=0.04)
    d = ImageDraw.Draw(layer)
    tx = cx + tri * 0.6 - tw / 2 - tri * 1.1
    h = size * 0.38
    d.polygon([(tx, cy - h), (tx, cy + h), (tx + h * 1.7, cy)], fill=(110, 30, 150, 255))
    d.polygon([(tx + 4, cy - h + 6), (tx + 4, cy + h - 6), (tx + h * 1.7 - 8, cy)], fill=(255, 255, 255, 255))
    if angle:
        layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(layer, (int(center[0] - layer.width / 2), int(center[1] - layer.height / 2)))


def classic_block(img, cx, top, scale=1.0, angle=0.0):
    """OHU / Fashion Social / Dress · Dance · Make Friends, centred on cx."""
    s = scale
    title(img, "OHU", (cx, top + 95 * s), int(170 * s), angle=angle)
    title(img, "Fashion Social", (cx + 10 * s, top + 220 * s), int(68 * s), angle=angle + 3, thick=0.03,
          outline=0.11, top=WHITE, bottom=LILAC)
    title(img, "Dress · Dance · Make Friends", (cx, top + 295 * s), int(34 * s), angle=angle + 2, thick=0.0,
          outline=0.09, top=WHITE, bottom=WHITE, drop=0.03)


def two_lines(img, first, second, at, size, angle, gap=1.25, shift=0.0):
    """A short two-line Korean line (오후에서, / 친구들과 함께해요!)."""
    x, y = at
    title(img, first, (x, y), size, angle=angle, thick=0.012, outline=0.075, drop=0.04)
    title(img, second, (x + size * shift, y + size * gap), size, angle=angle, thick=0.012, outline=0.075, drop=0.04)


JOBS = {}


def job(name, src):
    def deco(fn):
        JOBS[name] = (src, fn)
        return fn
    return deco


@job("a_square", "a_square.webp")
def a_square(img):
    erase(img, (600, 10, 1310, 380))
    classic_block(img, 960, 25, 1.0)


@job("a_square_small", "a_square_small.webp")
def a_square_small(img):
    k = 1672 / 1920
    erase(img, (int(600 * k), int(10 * k), int(1310 * k), int(380 * k)))
    classic_block(img, 960 * k, 25 * k, 1.0 * k)


@job("b_girls_white", "b_girls_white.webp")
def b_girls_white(img):
    # no title in the picture: the logo in the sky between the cafe and the club
    classic_block(img, 830, 0, 0.6)


@job("c_couple_beach", "c_couple_beach.webp")
def c_couple_beach(img):
    # no title in the picture: the logo in the sky over the middle
    classic_block(img, 730, 0, 0.6)


@job("d_billboard_couple", "d_billboard_couple.jpg")
def d_billboard_couple(img):
    erase(img, (130, 150, 800, 570))
    classic_block(img, 455, 175, 1.0, angle=4)
    erase(img, (180, 560, 580, 705), feather=30)
    two_lines(img, "지금, 오후에서", "친구들과 함께해요!", (330, 610), 50, 6, shift=0.5)
    fill_flat(img, (1440, 780, 1790, 880))
    play_label(img, (1600, 830), 50, angle=5)


@job("e_billboard_girls", "e_billboard_girls.jpg")
def e_billboard_girls(img):
    erase(img, (1100, 80, 1850, 560))
    classic_block(img, 1470, 100, 1.05, angle=8)
    erase(img, (100, 160, 460, 310), feather=30)
    two_lines(img, "오후에서,", "친구들과 함께해요!", (220, 205), 44, 10, shift=0.9)
    fill_flat(img, (1350, 855, 1760, 960))
    play_label(img, (1560, 905), 50, angle=5)


@job("f_boys_club", "f_boys_club.jpg")
def f_boys_club(img):
    erase(img, (150, 15, 810, 420))
    classic_block(img, 445, 30, 1.0, angle=6)
    erase(img, (1290, 35, 1830, 150), feather=20, radius=35)
    erase(img, (1330, 110, 1760, 200), feather=20, radius=35)
    two_lines(img, "오후에서,", "친구들과 함께해요!", (1420, 105), 54, 8, shift=2.2)
    fill_flat(img, (1450, 905, 1850, 1005))
    play_label(img, (1645, 955), 50, angle=4)


LOGO_OUT = os.path.join(ROOT, "docs", "04_ART", "logo")


def logo_png(path, text, size, **style):
    """A title on a transparent canvas, cropped to what was drawn."""
    canvas = Image.new("RGBA", (int(size * (len(text) + 2)), int(size * 3)), (0, 0, 0, 0))
    title(canvas, text, (canvas.width / 2, canvas.height / 2), size, **style)
    canvas.crop(canvas.getbbox()).save(path)


def flat_png(path, text, size, thick=0.035, tracking=0.0):
    """Plain white thick letters (the game tints them, ImageColor3)."""
    canvas = (int(size * (len(text) + 2)), int(size * 3))
    m = text_mask(text, size, int(size * thick), canvas, tracking)
    img = Image.new("RGBA", canvas, (255, 255, 255, 0))
    img.putalpha(m)
    img.crop(img.getbbox()).save(path)


def logo_pair_png(path, left, right, size, gap=0.35, left_tracking=0.0, **style):
    """Two words side by side (OHU 오후), each with its own letter spacing."""
    def word(text, tracking):
        c = Image.new("RGBA", (int(size * (len(text) * (1 + tracking) + 2)), int(size * 3)), (0, 0, 0, 0))
        title(c, text, (c.width / 2, c.height / 2), size, tracking=tracking, **style)
        return c.crop(c.getbbox())
    a, b = word(left, left_tracking), word(right, 0.0)
    space = int(size * gap)
    out = Image.new("RGBA", (a.width + space + b.width, max(a.height, b.height)), (0, 0, 0, 0))
    out.alpha_composite(a, (0, (out.height - a.height) // 2))
    out.alpha_composite(b, (a.width + space, (out.height - b.height) // 2))
    out.save(path)


# letter spacing of O H U (D-865, user: "O H U 알파벳 사이 간격 둬")
OHU_TRACKING = 0.12
# (with an outline the outlines need room too, or they run into one another)
OHU_TRACKING_OUTLINED = OHU_TRACKING + 2 * (0.015 + 0.07)


def logos():
    """The game-name images used in the game (D-864): loading screen, photo
    booth bands, photo strip footer."""
    os.makedirs(LOGO_OUT, exist_ok=True)
    logo_png(os.path.join(LOGO_OUT, "ohu_logo.png"), "OHU", 300, thick=0.015, outline=0.07, tracking=OHU_TRACKING_OUTLINED)
    logo_pair_png(os.path.join(LOGO_OUT, "ohu_logo_ko.png"), "OHU", "오후", 260, gap=-0.1, left_tracking=OHU_TRACKING_OUTLINED,
                  thick=0.015, outline=0.07)
    flat_png(os.path.join(LOGO_OUT, "ohu_flat_white.png"), "OHU", 300, thick=0.015, tracking=OHU_TRACKING)
    print("wrote logos")


def main(names):
    if names == ["logos"]:
        logos()
        return
    os.makedirs(OUT, exist_ok=True)
    for name in names or JOBS:
        src, fn = JOBS[name]
        img = Image.open(os.path.join(SRC, src)).convert("RGBA")
        fn(img)
        img.convert("RGB").save(os.path.join(OUT, name + ".png"))
        print("wrote", name)


if __name__ == "__main__":
    main(sys.argv[1:])
