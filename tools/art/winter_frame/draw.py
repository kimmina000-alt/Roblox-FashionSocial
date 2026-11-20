# (D-1874) The winter attendance event's frame "winter2026" (오후의 첫눈), drawn in code: an icy
# frame with a snow-lace scalloped edge, snowflakes, a snowman peeking at the bottom left and
# "OHU" with snowflakes in the footer. Drawn straight in the game's strip geometry
# (PhotoRender.newStrip: 4:3 cells, 0.35 gaps, a 1.4 footer), with a margin around for the
# pieces that reach past the strip, so no warp is needed (unlike tools/art/opening_frame).
#   python draw.py   -> winter_2x2.png, winter_1x4.png, info.json (PhotoConfig art rectangles)
import json, math, random
from PIL import Image, ImageDraw, ImageFont

SS = 3                      # supersampling
GAP, CW, CH, FOOT = 0.35, 4.0, 3.0, 1.4
MARGIN = 0.55               # units around the strip for the snowman / flakes / lace
FONT = "C:/Windows/Fonts/seguibl.ttf"

ICE_TOP = (244, 250, 255)
ICE_BOT = (206, 226, 250)
LINE = (120, 170, 228)
LINE_SOFT = (178, 208, 242)
WHITE = (255, 255, 255)
NAVY = (60, 96, 160)


def layout(cols, rows):
    w = cols * CW + (cols + 1) * GAP
    h = rows * CH + (rows + 1) * GAP + FOOT
    cells = [(GAP + c * (CW + GAP), GAP + r * (CH + GAP)) for r in range(rows) for c in range(cols)]
    return w, h, cells


def draw_frame(cols, rows, out, seed):
    rnd = random.Random(seed)
    w, h, cells = layout(cols, rows)
    W, H = w + 2 * MARGIN, h + 2 * MARGIN
    k = 1024 / max(W, H) * SS
    px = lambda u: u * k
    P = lambda x, y: (px(x + MARGIN), px(y + MARGIN))
    img = Image.new("RGBA", (round(px(W)), round(px(H))), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def rrect(x0, y0, x1, y1, r, fill=None, outline=None, width=0):
        d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=px(r), fill=fill, outline=outline, width=round(px(width)) if width else 0)

    # 1. snow lace: white scallops along the edge, half outside the body
    step, rad = 0.26, 0.15
    edge = []
    n = max(1, round(w / step)); edge += [(i * w / n, 0) for i in range(n + 1)] + [(i * w / n, h) for i in range(n + 1)]
    n = max(1, round(h / step)); edge += [(0, i * h / n) for i in range(n + 1)] + [(w, i * h / n) for i in range(n + 1)]
    for (x, y) in edge:
        cx, cy = P(x, y)
        d.ellipse([cx - px(rad), cy - px(rad), cx + px(rad), cy + px(rad)], fill=WHITE, outline=LINE_SOFT, width=round(px(0.025)))

    # 2. the body: vertical ice gradient in a rounded rectangle
    body = Image.new("RGBA", img.size, (0, 0, 0, 0))
    grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    y0, y1 = P(0, 0)[1], P(0, h)[1]
    for y in range(int(y0), int(y1) + 1):
        t = (y - y0) / max(1, y1 - y0)
        c = tuple(round(ICE_TOP[i] + (ICE_BOT[i] - ICE_TOP[i]) * t) for i in range(3))
        gd.line([(0, y), (img.size[0], y)], fill=c + (255,))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([P(0, 0), P(w, h)], radius=px(0.3), fill=255)
    body.paste(grad, (0, 0), mask)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    rrect(0, 0, w, h, 0.3, outline=WHITE, width=0.07)
    rrect(0.1, 0.1, w - 0.1, h - 0.1, 0.24, outline=LINE_SOFT, width=0.025)

    # 3. falling snow: soft dots on the frame (not over the photos)
    def in_cell(x, y, pad=0.06):
        return any(cx - pad <= x <= cx + CW + pad and cy - pad <= y <= cy + CH + pad for cx, cy in cells)
    snow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(snow)
    for _ in range(int(w * h * 3)):
        x, y = rnd.uniform(0.12, w - 0.12), rnd.uniform(0.12, h - 0.12)
        if in_cell(x, y):
            continue
        r = rnd.uniform(0.018, 0.045)
        cx, cy = P(x, y)
        # (blended on a layer: ImageDraw on RGBA replaces alpha, which made the dots see-through)
        sd.ellipse([cx - px(r), cy - px(r), cx + px(r), cy + px(r)], fill=(255, 255, 255, rnd.randint(170, 255)))
    img.alpha_composite(snow)
    d = ImageDraw.Draw(img)

    # 4. the photo holes: a white rim with a blue line, then cut out
    for (cx, cy) in cells:
        rrect(cx - 0.07, cy - 0.07, cx + CW + 0.07, cy + CH + 0.07, 0.22, fill=WHITE)
        rrect(cx - 0.035, cy - 0.035, cx + CW + 0.035, cy + CH + 0.035, 0.2, outline=LINE_SOFT, width=0.02)
    hole = Image.new("L", img.size, 0)
    hd = ImageDraw.Draw(hole)
    for (cx, cy) in cells:
        hd.rounded_rectangle([P(cx + 0.04, cy + 0.04), P(cx + CW - 0.04, cy + CH - 0.04)], radius=px(0.16), fill=255)
    a = img.getchannel("A")
    a = Image.composite(Image.new("L", img.size, 0), a, hole)
    img.putalpha(a)
    d = ImageDraw.Draw(img)

    # 5. snowflakes
    def flake(x, y, r, col=WHITE, edge_col=LINE, wdt=0.05, rot=0.0):
        cx, cy = P(x, y)
        def arms(colour, width):
            for i in range(6):
                ang = rot + i * math.pi / 3
                ex, ey = cx + math.cos(ang) * px(r), cy + math.sin(ang) * px(r)
                d.line([(cx, cy), (ex, ey)], fill=colour, width=width)
                for f in (0.45, 0.72):
                    bx, by = cx + math.cos(ang) * px(r * f), cy + math.sin(ang) * px(r * f)
                    for s in (-1, 1):
                        a2 = ang + s * math.pi / 4
                        L = px(r * (0.34 if f < 0.6 else 0.22))
                        d.line([(bx, by), (bx + math.cos(a2) * L, by + math.sin(a2) * L)], fill=colour, width=width)
            rr = px(r * 0.16)
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=colour)
        arms(edge_col, max(1, round(px(wdt * 2.1))))
        arms(col, max(1, round(px(wdt))))

    # big crest flake at the top left corner, one at the top right, small ones on the border
    flake(0.18, 0.12, 0.62, rot=0.26)
    flake(w - 0.25, 0.3, 0.38, rot=0.1)
    flake(w + 0.05, h * 0.45, 0.3, rot=0.5)
    for _ in range(90):
        x, y = rnd.uniform(0.15, w - 0.15), rnd.uniform(0.15, h - FOOT + 0.2)
        if in_cell(x, y, 0.18):
            continue
        flake(x, y, rnd.uniform(0.08, 0.13), col=(255, 255, 255), edge_col=LINE_SOFT, wdt=0.022, rot=rnd.uniform(0, 1))

    # 6. footer: ❄ OHU ❄ (flakes drawn, the letters in a heavy font with a white edge)
    fy = h - FOOT / 2 - GAP / 4
    font = ImageFont.truetype(FONT, round(px(0.78)))
    txt = "OHU"
    tw = d.textlength(txt, font=font)
    tx, ty = P(w / 2, fy)
    d.text((tx - tw / 2, ty), txt, font=font, fill=NAVY, anchor="lm", stroke_width=round(px(0.07)), stroke_fill=WHITE)
    off = tw / 2 / k + 0.42
    flake(w / 2 - off, fy, 0.26, col=(150, 200, 250), edge_col=WHITE, wdt=0.05)
    flake(w / 2 + off, fy, 0.26, col=(150, 200, 250), edge_col=WHITE, wdt=0.05)

    # 7. a snowman peeking at the bottom left (red scarf, carrot nose)
    sx, sy, s = -0.1, h - 0.55, 0.62 if cols > 1 else 0.5
    def circle(x, y, r, fill, outline=LINE, width=0.05):
        cx, cy = P(x, y)
        d.ellipse([cx - px(r), cy - px(r), cx + px(r), cy + px(r)], fill=fill, outline=outline, width=round(px(width)))
    circle(sx, sy, s, WHITE)                      # body
    circle(sx + 0.05, sy - s * 1.25, s * 0.7, WHITE)  # head
    hx, hy = sx + 0.05, sy - s * 1.25
    for ex in (-0.22, 0.22):
        circle(hx + ex * s, hy - 0.1 * s, 0.06 * s / 0.62, (40, 40, 60), outline=None)
    # carrot
    nx, ny = P(hx, hy + 0.08 * s)
    d.polygon([(nx, ny - px(0.06)), (nx, ny + px(0.06)), (nx + px(0.32 * s), ny + px(0.02))], fill=(255, 140, 50))
    # blush
    for ex in (-0.38, 0.38):
        cx, cy = P(hx + ex * s, hy + 0.2 * s)
        d.ellipse([cx - px(0.08), cy - px(0.05), cx + px(0.08), cy + px(0.05)], fill=(255, 170, 190))
    # scarf
    scy = sy - s * 0.78
    d.rounded_rectangle([P(sx - s * 0.62, scy - 0.09), P(sx + s * 0.72, scy + 0.09)], radius=px(0.08), fill=(230, 60, 80), outline=(170, 30, 50), width=round(px(0.025)))
    d.rounded_rectangle([P(sx + s * 0.25, scy), P(sx + s * 0.5, scy + 0.5 * s)], radius=px(0.06), fill=(230, 60, 80), outline=(170, 30, 50), width=round(px(0.025)))
    # a knit hat
    d.pieslice([P(hx - s * 0.55, hy - s * 0.95), P(hx + s * 0.55, hy - s * 0.05)], 180, 360, fill=(90, 140, 230), outline=LINE, width=round(px(0.03)))
    d.rounded_rectangle([P(hx - s * 0.6, hy - s * 0.58), P(hx + s * 0.6, hy - s * 0.42)], radius=px(0.05), fill=WHITE, outline=LINE, width=round(px(0.02)))
    circle(hx, hy - s * 0.98, 0.1 * s / 0.62 + 0.03, WHITE, width=0.02)

    out_img = img.resize((round(img.size[0] / SS), round(img.size[1] / SS)), Image.LANCZOS)
    out_img.save(out)
    info = dict(x=-MARGIN / w, y=-MARGIN / h, w=W / w, h=H / h, px=list(out_img.size))
    print(out, info)
    return info


if __name__ == "__main__":
    i1 = draw_frame(2, 2, "winter_2x2.png", 7)
    i2 = draw_frame(1, 4, "winter_1x4.png", 11)
    json.dump({"2x2": i1, "1x4": i2}, open("info.json", "w"), indent=1)
