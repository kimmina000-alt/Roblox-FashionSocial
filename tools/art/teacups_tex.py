# (D-1432) 회전컵: re-UV the user's cup.glb (cup + handle, merged into one mesh) and teapot.glb and
# paint them from the photo (white cups with a coloured drip band at the top, white inside; the
# teapot blue at the foot, white body, a dark-green drip band, blue lid, yellow knob). The cup had
# no inside (an outer shell only: from above one saw through it): an inside is added.
# Cylindrical mapping (u = angle round the middle, v = height); seam triangles keep u continuous.
# Writes CupTex.glb (green band) + CupTex_<colour>.png for the other cups, TeapotTex.glb.
# python tools/art/teacups_tex.py  (copies in docs/04_ART/park/teacups_tex)
import json, struct, io, math, sys, numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "D:/Roblox/오후/3D 물/"
OUT = SRC + "teacups_tex/"
W = 1024

def load(p):
    b = open(p, 'rb').read(); jl = struct.unpack('<I', b[12:16])[0]; js = json.loads(b[20:20 + jl]); bin_ = b[20 + jl + 8:]
    def acc(i, dt, n):
        a = js['accessors'][i]; bv = js['bufferViews'][a['bufferView']]; o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        r = np.frombuffer(bin_, dtype=dt, count=a['count'] * n, offset=o); return r.reshape(-1, n) if n > 1 else r
    meshes = []
    for node in js['nodes']:
        for pr in js['meshes'][node['mesh']]['primitives']:
            P = acc(pr['attributes']['POSITION'], np.float32, 3) + np.array(node.get('translation', [0, 0, 0]))
            N = acc(pr['attributes']['NORMAL'], np.float32, 3)
            a = js['accessors'][pr['indices']]
            I = acc(pr['indices'], {5123: np.uint16, 5125: np.uint32}[a['componentType']], 1).reshape(-1, 3)
            meshes.append((node['name'], P.copy(), N.copy(), I))
    return meshes

def write_glb(dst, name, P, N, UV, png):
    I = np.arange(len(P), dtype=np.uint32)
    blobs = [P.astype(np.float32).tobytes(), N.astype(np.float32).tobytes(), UV.astype(np.float32).tobytes(), I.tobytes(), png]
    views = []; off = 0; data = b''
    for k, bb in enumerate(blobs):
        pad = (-len(bb)) % 4; v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(bb)}
        if k < 3: v['target'] = 34962
        elif k == 3: v['target'] = 34963
        views.append(v); data += bb + b'\0' * pad; off += len(bb) + pad
    js = {'asset': {'version': '2.0', 'generator': 'ohu teacups_tex'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
          'nodes': [{'mesh': 0, 'name': name}],
          'meshes': [{'name': name, 'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0}]}],
          'materials': [{'name': name + '_mat', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0, 'roughnessFactor': 0.6}}],
          'textures': [{'source': 0}], 'images': [{'bufferView': 4, 'mimeType': 'image/png', 'name': name + '_tex'}],
          'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': len(P), 'type': 'VEC3', 'min': P.min(0).tolist(), 'max': P.max(0).tolist()},
                        {'bufferView': 1, 'componentType': 5126, 'count': len(N), 'type': 'VEC3'},
                        {'bufferView': 2, 'componentType': 5126, 'count': len(UV), 'type': 'VEC2'},
                        {'bufferView': 3, 'componentType': 5125, 'count': len(I), 'type': 'SCALAR'}],
          'bufferViews': views, 'buffers': [{'byteLength': len(data)}]}
    j = json.dumps(js).encode(); j += b' ' * ((-len(j)) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(data)) + struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(data), 0x004E4942) + data
    open(dst, 'wb').write(out)

def drips(d, y0, y1, color, seed, wave=0.03, n=7):
    """a band from the top down to y1 with a wavy lower edge and round drips (pixel rows y0..y1)"""
    rnd = np.random.RandomState(seed)
    pts = [(0, y0)]
    for x in range(0, W + 1, 8):
        pts.append((x, y1 + math.sin(x / W * 2 * math.pi * 3) * W * wave))
    pts.append((W, y0))
    d.polygon(pts, fill=color)
    for k in range(n):
        x = (k + 0.5) / n * W + rnd.uniform(-30, 30)
        base = y1 + math.sin(x / W * 2 * math.pi * 3) * W * wave
        L = rnd.uniform(0.06, 0.14) * W; r = rnd.uniform(14, 22)
        d.rectangle([x - r, base - 4, x + r, base + L], fill=color)
        d.ellipse([x - r, base + L - r, x + r, base + L + r], fill=color)

def cyl_uv(P, I, center, ymin, ymax, vtop=0.0, vbot=0.8):
    """per-triangle cylindrical UVs, u continuous across the seam"""
    UV = []
    for t in I:
        v = P[t]
        u = (np.arctan2(v[:, 2] - center[2], v[:, 0] - center[0]) / (2 * math.pi)) % 1.0
        if u.max() - u.min() > 0.5: u = np.where(u < 0.5, u + 1, u)
        vv = vtop + (1 - (v[:, 1] - ymin) / (ymax - ymin)) * (vbot - vtop)
        UV.extend(zip(u, vv))
    return np.array(UV, np.float32)

WHITE = (248, 248, 246)
# ---------------------------------------------------------------- cup
CUPS = {'green': (70, 150, 95), 'red': (214, 60, 58), 'yellow': (244, 196, 52), 'blue': (88, 176, 228), 'darkgreen': (52, 84, 58)}
def cup_image(col):
    img = Image.new('RGB', (W, W), WHITE); d = ImageDraw.Draw(img)
    # side (v 0..0.8 = top..bottom of the cup)
    drips(d, 0, int(0.8 * W * 0.30), col, seed=3)
    d.rectangle([0, 0, W, int(0.8 * W * 0.035)], fill=col)              # the rim
    yb = int(0.8 * W * 0.86); d.rectangle([0, yb, W, yb + 10], fill=(70, 150, 215))  # thin blue line low down
    # swatches (v 0.85..1): inside white, floor pale grey
    d.rectangle([0, int(0.86 * W), W // 2, W], fill=WHITE)
    d.rectangle([W // 2, int(0.86 * W), W, W], fill=(214, 220, 228))
    return img.filter(ImageFilter.SMOOTH)

meshes = load(SRC + "cup.glb")
cupP = np.vstack([m[1] for m in meshes]); 
# merge the handle into the cup
allP, allN, allI, base = [], [], [], 0
for name, P, N, I in meshes:
    allP.append(P); allN.append(N); allI.append(I + base); base += len(P)
P = np.vstack(allP); N = np.vstack(allN); I = np.vstack(allI)
hand = np.zeros(len(I), bool); hand[len(meshes[0][3]):] = True
lo, hi = meshes[0][1].min(0), meshes[0][1].max(0); C = (lo + hi) / 2
side = cyl_uv(P, I, C, lo[1], hi[1])
outP, outN, outUV = [], [], []
SW_IN = (0.25, 0.93); SW_FLOOR = (0.75, 0.93)
for k, t in enumerate(I):
    v = P[t]; n = N[t].mean(0); n = n / (np.linalg.norm(n) + 1e-9); c = v.mean(0)
    r = c - C; r[1] = 0
    outward = np.dot(n, r) > 0 or n[1] < -0.5
    if hand[k]:
        uv = [SW_IN] * 3
    elif outward and abs(n[1]) < 0.95:
        uv = side[k * 3:k * 3 + 3].tolist()
    elif n[1] > 0.5:
        uv = [SW_FLOOR] * 3
    else:
        uv = [SW_IN] * 3
    for j in range(3):
        outP.append(v[j]); outN.append(N[t[j]]); outUV.append(uv[j])
    # the cup's inside: the outer wall again, turned in, a hair inward (and the bottom, as a floor)
    if not hand[k] and outward:
        inner = SW_FLOOR if n[1] < -0.5 else SW_IN
        for j in (0, 2, 1):
            outP.append(v[j] - n * 0.02); outN.append(-N[t[j]]); outUV.append(inner)
outP = np.array(outP, np.float32); outN = np.array(outN, np.float32); outUV = np.array(outUV, np.float32)
for name, col in CUPS.items():
    img = cup_image(col); img.save(OUT + f"CupTex_{name}.png")
buf = io.BytesIO(); cup_image(CUPS['green']).save(buf, 'PNG')
write_glb(OUT + "CupTex.glb", "CupTex", outP, outN, outUV, buf.getvalue())
print("cup", len(outP) // 3, "tris, bounds", outP.min(0).round(3).tolist(), outP.max(0).round(3).tolist())

# ---------------------------------------------------------------- teapot
name, P, N, I = load(SRC + "teapot.glb")[0]
lo, hi = P.min(0), P.max(0); C = np.array([0, 0, 0.0])
body = P[(P[:, 2] > -1.05) & (P[:, 2] < 1.05)]
C = np.array([(body[:, 0].max() + body[:, 0].min()) / 2, 0, (body[:, 2].max() + body[:, 2].min()) / 2])
UV = cyl_uv(P, I, C, lo[1], hi[1], 0.0, 1.0)
img = Image.new('RGB', (W, W), WHITE); d = ImageDraw.Draw(img)
H = W
def row(v): return int(v * H)
blue = (70, 150, 215); gold = (232, 190, 70); green = (52, 84, 58)
d.rectangle([0, row(0.0), W, row(0.09)], fill=gold)                      # knob (top)
d.rectangle([0, row(0.09), W, row(0.26)], fill=blue)                     # lid
for k in range(12):
    x = (k + 0.5) / 12 * W; d.ellipse([x - 10, row(0.17) - 10, x + 10, row(0.17) + 10], fill=WHITE)
d.rectangle([0, row(0.26), W, row(0.28)], fill=gold)
drips(d, row(0.28), row(0.40), green, seed=7, n=8)                        # the drip band under the lid
d.rectangle([0, row(0.70), W, H], fill=blue)                              # foot
pts = [(0, row(0.70))] + [(x, row(0.70) + math.sin(x / W * 2 * math.pi * 6) * 12) for x in range(0, W + 1, 8)] + [(W, row(0.70))]
d.line([(x, row(0.69) + math.sin(x / W * 2 * math.pi * 6) * 12) for x in range(0, W + 1, 8)], fill=gold, width=10)
img = img.filter(ImageFilter.SMOOTH); img.save(OUT + "TeapotTex.png")
buf = io.BytesIO(); img.save(buf, 'PNG')
dP = P[I.ravel()]; dN = N[I.ravel()]
write_glb(OUT + "TeapotTex.glb", "TeapotTex", dP, dN, UV, buf.getvalue())
print("teapot", len(dP) // 3, "tris, bounds", dP.min(0).round(3).tolist(), dP.max(0).round(3).tolist())
