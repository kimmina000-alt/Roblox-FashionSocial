import math
import sys
from PIL import Image

D = r"C:\Users\ma912\.claude\projects\D--Roblox-Roblox-FashionSocial\670ab8b6-e153-4c80-997e-c788952dde88\tool-results"
tiles = [
    (60, -140, "mcp-Roblox_Studio-blob-1794413331061-r2vpo8.jpg"),
    (60, 110, "mcp-Roblox_Studio-blob-1794413340880-bk0d2d.jpg"),
    (185, -140, "mcp-Roblox_Studio-blob-1794413349777-piuiol.jpg"),
    (185, 110, "mcp-Roblox_Studio-blob-1794413358813-ams3o2.jpg"),
    (310, -140, "mcp-Roblox_Studio-blob-1794413369128-m3lyyo.jpg"),
    (310, 110, "mcp-Roblox_Studio-blob-1794413377641-jthqj7.jpg"),
    (435, -140, "mcp-Roblox_Studio-blob-1794413386304-dnpo2c.jpg"),
    (435, 110, "mcp-Roblox_Studio-blob-1794413394751-secezj.jpg"),
    (560, -140, "mcp-Roblox_Studio-blob-1794413403907-7l41aa.jpg"),
    (560, 110, "mcp-Roblox_Studio-blob-1794413412804-qv3nzm.jpg"),
    (685, -140, "mcp-Roblox_Studio-blob-1794413423302-kf1q6t.jpg"),
    (685, 110, "mcp-Roblox_Studio-blob-1794413433825-rtoep8.jpg"),
]
W, H = 1547, 801
k = H / (2 * 400 * math.tan(math.radians(10)))
halfV, halfU = (W / 2) / k, (H / 2) / k
vmin, vmax = -140 - halfV, 110 + halfV
umin, umax = 60 - halfU, 685 + halfU
cw, ch = int((vmax - vmin) * k + 1), int((umax - umin) * k + 1)
canvas = Image.new("RGB", (cw, ch))
for u, v, f in tiles:
    im = Image.open(D + "\\" + f).convert("RGB").resize((W, H))
    left = int(round((v - halfV - vmin) * k))
    top = int(round((umax - (u + halfU)) * k))
    canvas.paste(im, (left, top))
out = sys.argv[1]
canvas.save(out, quality=92)
print(cw, ch, round(k, 3))
