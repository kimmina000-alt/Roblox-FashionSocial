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
    kl = Image.new("RGBA", canvas, (255, 255, 255, 0)) if white else grad.copy()
    kl.putalpha(ko_m)
    out = Image.alpha_composite(out, kl)
    return out.crop(out.getbbox())


KS = int(S * 0.36)
fonts = {
    "J": ("주아", load(os.path.join(FD, "Jua-Regular.ttf"), KS)),
}
rows = [
    ("S3R  주아 · 오른쪽 U에 맞춤", stacked(fonts["J"][1], KS, "right"), stacked(fonts["J"][1], KS, "right", glow=True)),
]
label = ImageFont.truetype(r"C:\Windows\Fonts\malgunbd.ttf", 30)
cw, ch = 820, 520
sheet = Image.new("RGB", (cw * 2, ch * len(rows)), (255, 255, 255))
d = ImageDraw.Draw(sheet)
for r, (name, a, b) in enumerate(rows):
    for c, (im0, bg, tag) in enumerate([(a, (255, 255, 255), "G1"), (b, NAVY, "G3")]):
        x0, y0 = c * cw, r * ch
        d.rectangle((x0, y0, x0 + cw, y0 + ch), fill=bg)
        s = min((cw - 160) / im0.width, (ch - 120) / im0.height)
        im = im0.resize((int(im0.width * s), int(im0.height * s)), Image.LANCZOS)
        sheet.paste(im, (x0 + (cw - im.width) // 2, y0 + 60 + (ch - 80 - im.height) // 2), im)
        d.text((x0 + 22, y0 + 14), name + "  ·  " + tag, font=label, fill=(40, 40, 50) if c == 0 else (235, 235, 245))
    a.save(os.path.join(OUT, name.split()[0] + "_G1.png"))
    b.save(os.path.join(OUT, name.split()[0] + "_G3.png"))
sheet.save(r"D:\Roblox\Roblox-FashionSocial\docs\04_ART\logo\brand_stacked_s3r.jpg", quality=92)
print(sheet.size)

final = r"D:\Roblox\Roblox-FashionSocial\docs\04_ART\logo"
stacked(fonts["J"][1], KS, "right", white=True).save(os.path.join(final, "ohu_main_white.png"))
stacked(fonts["J"][1], KS, "right").save(os.path.join(final, "ohu_main_outline.png"))
print("finals")