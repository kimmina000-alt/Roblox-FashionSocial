"""Main logo (D-867): OHU on top (white letters, sunset-gradient outline), small 오후 under it in a
gradient fill, from the user's mock-up (images/1007.png)."""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FD = r"D:\Roblox\Roblox-FashionSocial\docs\04_ART\fonts"
BAGEL = r"D:\Roblox\Roblox-FashionSocial\docs\04_ART\fonts\BagelFatOne-Regular.ttf"
OUT = r"D:\Roblox\Roblox-FashionSocial\docs\04_ART\logo\brand"
G = [(255, 179, 107), (255, 111, 145), (122, 92, 255)]
NAVY = (30, 27, 58)
S = 640  # OHU font size


def load(path, size, wght=None):
    f = ImageFont.truetype(path, size)
    if wght:
        f.set_variation_by_axes([wght])
    return f


def text_mask(text, f, stroke, gap, canvas, origin):
    m = Image.new("L", canvas, 0)
    d = ImageDraw.Draw(m)
    x, y = origin
    for ch in text:
        d.text((x, y), ch, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
        x += f.getlength(ch) + gap
    return m


def hgrad(canvas, x0, x1, darken=1.0):
    g = Image.new("RGB", canvas)
    d = ImageDraw.Draw(g)
    for x in range(canvas[0]):
        t = min(1, max(0, (x - x0) / max(1, x1 - x0)))
        a, b, u = (G[0], G[1], t / 0.5) if t < 0.5 else (G[1], G[2], (t - 0.5) / 0.5)
        d.line((x, 0, x, canvas[1]), fill=tuple(int((a[i] + (b[i] - a[i]) * u) * darken) for i in range(3)))
    return g.convert("RGBA")


def stacked(ko_font, ko_size, align="center", glow=False, ko_gap_ratio=0.06, white=False):
    canvas = (int(S * 6), int(S * 4))
    bagel = load(BAGEL, S)
    t, o = int(S * 0.015), int(S * 0.07)
    gap = S * (0.12 + 2 * (0.015 + 0.07)) / 2  # (D-867, user: half the room between O H U)
    probe = text_mask("OHU", bagel, t + o, gap, canvas, (0, 0))
    bb = probe.getbbox()
    ox, oy = (canvas[0] - (bb[2] - bb[0])) / 2 - bb[0], S * 0.6 - bb[1]
    fill_m = text_mask("OHU", bagel, t, gap, canvas, (ox, oy))
    edge_m = text_mask("OHU", bagel, t + o, gap, canvas, (ox, oy))
    eb = edge_m.getbbox()

    # 오후 under OHU
    kgap = ko_size * ko_gap_ratio
    kprobe = text_mask("오후", ko_font, 0, kgap, canvas, (0, 0))
    kb = kprobe.getbbox()
    kw = kb[2] - kb[0]
    if align == "center":
        kx = (eb[0] + eb[2]) / 2 - kw / 2
    else:  # right: ends where the U ends
        kx = eb[2] - o - kw
    ky = eb[3] + S * 0.10
    ko_m = text_mask("오후", ko_font, 0, kgap, canvas, (kx - kb[0], ky - kb[1]))

    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    grad = hgrad(canvas, eb[0], eb[2])
    if glow:
        gm = ImageChops.lighter(edge_m, ko_m).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(S * 0.12))
        gl = grad.copy()
        gl.putalpha(gm.point(lambda v: int(v * 0.75)))
        out = Image.alpha_composite(out, gl)
        dl = hgrad(canvas, eb[0], eb[2], 0.55)
        dl.putalpha(ImageChops.offset(edge_m, 0, int(S * 0.04)))
        out = Image.alpha_composite(out, dl)
    if not white:
        el = grad.copy()
        el.putalpha(edge_m)
        out = Image.alpha_composite(out, el)
    fl = Image.new("RGBA", canvas, (255, 255, 255, 0))
    fl.putalpha(fill_m)
    out = Image.alpha_composite(out, fl)
    if glow:
        # (on busy thumbnails the gradient 오후 sank into its own glow: a white rim)
        rim = Image.new("RGBA", canvas, (255, 255, 255, 0))
        rim.putalpha(ko_m.filter(ImageFilter.MaxFilter(2 * int(KS * 0.05) + 1)))
        out = Image.alpha_composite(out, rim)
    kl = Image.new("RGBA", canvas, (255, 255, 255, 0)) if white else grad.copy()
    kl.putalpha(ko_m)
    out = Image.alpha_composite(out, kl)
    return out.crop(out.getbbox())


KS = int(S * 0.36)
JUA = load(os.path.join(FD, "Jua-Regular.ttf"), KS)
FINAL = r"D:\Roblox\Roblox-FashionSocial\docs\04_ART\logo"


def main_logo(style="white"):
    """The main logo (D-867): "white" (no outline, the default), "outline"
    (white letters, gradient outline) or "glow" (outline + 3D drop + glow, for
    thumbnails)."""
    if style == "white":
        return stacked(JUA, KS, "right", white=True)
    return stacked(JUA, KS, "right", glow=(style == "glow"))


def ohu_only_white():
    """Just OHU in plain white, with the main logo's letter spacing (photo
    strip footers, the photo booth bands)."""
    canvas = (int(S * 6), int(S * 2))
    bagel = load(BAGEL, S)
    gap = S * (0.12 + 2 * (0.015 + 0.07)) / 2
    m = text_mask("OHU", bagel, int(S * 0.015), gap, canvas, (S * 0.5, S * 0.3))
    img = Image.new("RGBA", canvas, (255, 255, 255, 0))
    img.putalpha(m)
    return img.crop(img.getbbox())


def solid_white(img):
    """(D-874, user: "테두리 뭐야 못생겼어") every pixel white, only the alpha
    kept: the see-through pixels round the letters were black, and Roblox's
    scaling blended them into a dark rim"""
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.putalpha(img.getchannel("A"))
    return out


if __name__ == "__main__":
    solid_white(main_logo("white")).save(os.path.join(FINAL, "ohu_main_white.png"))
    main_logo("outline").save(os.path.join(FINAL, "ohu_main_outline.png"))
    main_logo("glow").save(os.path.join(FINAL, "ohu_main_glow.png"))
    solid_white(ohu_only_white()).save(os.path.join(FINAL, "ohu_white.png"))
    print("wrote main logos")