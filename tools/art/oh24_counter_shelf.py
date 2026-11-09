# OH24: the shelf behind the counter (D-1123, user 2026-11-09: "편의점 카운터 뒤에
# 파트에도 진열장 같은 이미지 넣어"). A drawn picture, 2:1 for the 20 x 10 block
# (Workspace.front): a dark wall unit with lit shelves of small goods sold at a
# Korean convenience store counter: gum and candy boxes, chocolate bars, jelly
# packs, lighter-free small goods (phone chargers, batteries, earphones in
# blister packs), gift cards. No tobacco or alcohol (D-311).
# python tools/art/oh24_counter_shelf.py  ->  docs/04_ART/textures/props/oh24_shelf_counter.png
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 2048, 1024
random.seed(1123)
img = Image.new("RGB", (W, H), (22, 22, 28))
d = ImageDraw.Draw(img)

# the unit: frame, back panel, top sign band
d.rectangle([0, 0, W, H], fill=(28, 28, 34))
d.rectangle([24, 24, W - 24, H - 24], fill=(40, 40, 48))
band = 110
d.rectangle([24, 24, W - 24, 24 + band], fill=(18, 18, 22))
# two lit sign boxes in the band (OH24 colours)
def sign(x0, x1, top, bottom, back, text_col):
    d.rounded_rectangle([x0, top, x1, bottom], radius=10, fill=back)
    d.rectangle([x0 + 14, top + 22, x0 + 14 + (x1 - x0) * 0.42, top + 34], fill=text_col)
    d.rectangle([x0 + 14, top + 46, x0 + 14 + (x1 - x0) * 0.62, top + 60], fill=text_col)
sign(60, 980, 38, 120, (0, 168, 160), (230, 255, 252))
sign(1068, 1988, 38, 120, (246, 196, 48), (60, 40, 10))

BAYS = [(48, 1012), (1036, W - 48)]
SHELF_Y = [150, 370, 590, 810, H - 40]
PALETTE = [(232, 72, 80), (255, 170, 60), (250, 220, 80), (110, 200, 120), (70, 160, 230),
           (150, 110, 220), (240, 120, 180), (250, 250, 245), (60, 60, 70), (200, 90, 50)]

def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)

def box(x, y_bottom, w, h, col):
    # a product box standing on the shelf: front face, a light top edge, a label
    d.rectangle([x, y_bottom - h, x + w, y_bottom], fill=col)
    d.rectangle([x, y_bottom - h, x + w, y_bottom - h + 6], fill=shade(col, 1.25))
    d.rectangle([x + 4, y_bottom - h * 0.62, x + w - 4, y_bottom - h * 0.38], fill=shade(col, 0.6) if sum(col) > 500 else (250, 250, 250))
    d.rectangle([x, y_bottom - h, x + 3, y_bottom], fill=shade(col, 0.75))

def bag(x, y_bottom, w, h, col):
    # a snack / jelly pouch: rounded, a window, a crimp on top
    d.rounded_rectangle([x, y_bottom - h, x + w, y_bottom], radius=12, fill=col)
    d.rectangle([x + 6, y_bottom - h, x + w - 6, y_bottom - h + 10], fill=shade(col, 0.8))
    d.ellipse([x + w * 0.2, y_bottom - h * 0.6, x + w * 0.8, y_bottom - h * 0.2], fill=shade(col, 1.3))

def blister(x, y_top, w, h, col):
    # a hanging card with a clear bubble (chargers, batteries, earphones)
    d.rectangle([x, y_top, x + w, y_top + h], fill=(235, 235, 240))
    d.rectangle([x, y_top, x + w, y_top + 22], fill=col)
    d.ellipse([x + w / 2 - 7, y_top + 5, x + w / 2 + 7, y_top + 17], fill=(40, 40, 48))
    d.rounded_rectangle([x + 10, y_top + 34, x + w - 10, y_top + h - 14], radius=10, fill=(200, 214, 226))
    d.rounded_rectangle([x + w * 0.3, y_top + 50, x + w * 0.7, y_top + h - 30], radius=6, fill=shade(col, 0.7))

def jar(x, y_bottom, w, h, col):
    # a candy jar: clear glass, colourful sweets, a red lid
    d.rounded_rectangle([x, y_bottom - h, x + w, y_bottom], radius=14, fill=(190, 205, 215))
    for _ in range(26):
        cx = random.uniform(x + 10, x + w - 10)
        cy = random.uniform(y_bottom - h * 0.75, y_bottom - 10)
        r = random.uniform(6, 10)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=random.choice(PALETTE))
    d.rectangle([x - 4, y_bottom - h - 14, x + w + 4, y_bottom - h + 4], fill=(220, 50, 60))

for bx0, bx1 in BAYS:
    for i in range(len(SHELF_Y) - 1):
        top, bottom = SHELF_Y[i], SHELF_Y[i + 1]
        floor = bottom - 30
        # shelf light strip under the shelf above, and the shelf lip with price tags
        d.rectangle([bx0, top, bx1, top + 6], fill=(255, 250, 235))
        x = bx0 + 18
        kind = (i + (0 if bx0 < 500 else 1)) % 4
        while x < bx1 - 60:
            col = random.choice(PALETTE)
            if kind == 0:   # gum / candy boxes, small and many
                w, h = random.randint(44, 60), random.randint(90, 120)
                box(x, floor, w, h, col)
            elif kind == 1:  # chocolate bars standing, and candy jars
                if random.random() < 0.22 and x < bx1 - 140:
                    w, h = 110, 150
                    jar(x, floor, w, h, col)
                else:
                    w, h = random.randint(36, 46), random.randint(130, 160)
                    box(x, floor, w, h, col)
            elif kind == 2:  # jelly / snack pouches
                w, h = random.randint(70, 90), random.randint(120, 160)
                bag(x, floor, w, h, col)
            else:            # hanging cards: chargers, batteries, earphones, gift cards
                w, h = random.randint(80, 96), random.randint(150, 170)
                blister(x, top + 18, w, h, col)
            x += w + random.randint(6, 12)
        # the shelf lip with price tags
        d.rectangle([bx0, floor, bx1, floor + 22], fill=(232, 232, 236))
        tx = bx0 + 30
        while tx < bx1 - 60:
            d.rectangle([tx, floor + 4, tx + 46, floor + 18], fill=(250, 214, 60))
            tx += random.randint(110, 150)
    # the bay's side posts
    d.rectangle([bx0 - 10, 140, bx0, H - 30], fill=(20, 20, 24))
    d.rectangle([bx1, 140, bx1 + 10, H - 30], fill=(20, 20, 24))

# glass doors over each bay: a faint reflection band
glare = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glare)
for bx0, bx1 in BAYS:
    gd.polygon([(bx0 + 120, 140), (bx0 + 260, 140), (bx0 + 60, H - 30), (bx0 - 80, H - 30)], fill=46)
glare = glare.filter(ImageFilter.GaussianBlur(18))
img = Image.composite(Image.new("RGB", (W, H), (255, 255, 255)), img, glare)

out = r"docs/04_ART/textures/props/oh24_shelf_counter.png"
img.resize((1024, 512), Image.LANCZOS).save(out)
print("saved", out)
