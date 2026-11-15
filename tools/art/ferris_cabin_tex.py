# (D-1433) 관람차 칸: re-UV the user's "ferris wheel.glb" (one cabin: a rounded profile in Y-Z pushed
# along X) and paint it from the photos — a coloured body (pink / blue / yellow / sky / red), white
# window frames and see-through windows (the PNG's alpha: riders are seen inside), a coloured roof.
# The cabin had no inside: the walls are added again turned inwards (cream inside, same windows).
#   * the two round end faces (normal ±X): planar (z, y) → the upper area of the image
#   * the rim strip round the profile: u = angle round the X axis, v = x → the lower area
# Writes FerrisCabinTex.glb (pink) + FerrisCabinTex_<colour>.png. python tools/art/ferris_cabin_tex.py
import json, struct, io, math, numpy as np
from PIL import Image, ImageDraw

SRC = "D:/Roblox/오후/3D 물/"
OUT = SRC + "ferris_tex/"
W = 1024

b = open(SRC + "ferris wheel.glb", 'rb').read(); jl = struct.unpack('<I', b[12:16])[0]; js = json.loads(b[20:20 + jl]); bin_ = b[20 + jl + 8:]
pr = js['meshes'][0]['primitives'][0]
def acc(i, dt, n):
    a = js['accessors'][i]; bv = js['bufferViews'][a['bufferView']]; o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    r = np.frombuffer(bin_, dtype=dt, count=a['count'] * n, offset=o); return r.reshape(-1, n) if n > 1 else r
P = acc(pr['attributes']['POSITION'], np.float32, 3).copy(); N = acc(pr['attributes']['NORMAL'], np.float32, 3)
I = acc(pr['indices'], np.uint16, 1).reshape(-1, 3)
lo, hi = P.min(0), P.max(0); C = (lo + hi) / 2

END = (0.02, 0.02, 0.98, 0.48)    # image rect (u0, v0, u1, v1) for the end faces
RIM = (0.0, 0.52, 1.0, 0.98)      # for the strip round the profile

def paint(body):
    img = Image.new('RGBA', (W, W), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    white = (250, 250, 248, 255); glass = (205, 232, 245, 70); roof = tuple(int(c * 0.82) for c in body[:3]) + (255,)
    # end faces: body below, a big window with a white frame, a roof band
    x0, y0, x1, y1 = [int(v * W) for v in END]
    h = y1 - y0
    d.rectangle([x0, y0, x1, y1], fill=body)
    d.rectangle([x0, y0, x1, y0 + int(h * 0.16)], fill=roof)
    d.rounded_rectangle([x0 + 40, y0 + int(h * 0.20), x1 - 40, y0 + int(h * 0.66)], radius=40, fill=white)
    d.rounded_rectangle([x0 + 58, y0 + int(h * 0.20) + 18, x1 - 58, y0 + int(h * 0.66) - 18], radius=30, fill=glass)
    d.rectangle([(x0 + x1) // 2 - 8, y0 + int(h * 0.20), (x0 + x1) // 2 + 8, y0 + int(h * 0.66)], fill=white)  # middle bar
    d.rectangle([x0, y0 + int(h * 0.70), x1, y0 + int(h * 0.73)], fill=white)
    # rim strip: u = angle (0 = straight up, 0.25 / 0.75 = the sides, 0.5 = down); v = across (x)
    rx0, ry0, rx1, ry1 = [int(v * W) for v in RIM]
    d.rectangle([rx0, ry0, rx1, ry1], fill=body)
    for side in (0.25, 0.75):  # side windows round the profile's sides
        cx = int(rx0 + side * (rx1 - rx0)); half = int(0.15 * (rx1 - rx0))
        d.rectangle([cx - half, ry0 + 12, cx + half, ry1 - 12], fill=white)
        d.rectangle([cx - half + 12, ry0 + 26, cx + half - 12, ry1 - 26], fill=glass)
        for k in (-1, 0, 1):
            d.rectangle([cx + k * half // 2 - 5, ry0 + 12, cx + k * half // 2 + 5, ry1 - 12], fill=white)
    top = int(rx0 + 0.0 * (rx1 - rx0))
    d.rectangle([rx0, ry0, rx0 + int(0.08 * (rx1 - rx0)), ry1], fill=roof)
    d.rectangle([rx1 - int(0.08 * (rx1 - rx0)), ry0, rx1, ry1], fill=roof)
    return img

def uv_for(t):
    v = P[t]; n = N[t].mean(0); n = n / (np.linalg.norm(n) + 1e-9)
    if abs(n[0]) > 0.9:  # end face: planar (z, y)
        u = (v[:, 2] - lo[2]) / (hi[2] - lo[2]); w = 1 - (v[:, 1] - lo[1]) / (hi[1] - lo[1])
        return np.stack([END[0] + u * (END[2] - END[0]), END[1] + w * (END[3] - END[1])], 1)
    ang = (np.arctan2(v[:, 2] - C[2], v[:, 1] - C[1]) / (2 * math.pi)) % 1.0  # 0 = up (+y)
    if ang.max() - ang.min() > 0.5: ang = np.where(ang < 0.5, ang + 1, ang)
    x = (v[:, 0] - lo[0]) / (hi[0] - lo[0])
    return np.stack([RIM[0] + ang * (RIM[2] - RIM[0]), RIM[1] + x * (RIM[3] - RIM[1])], 1)

outP, outN, outUV = [], [], []
for t in I:
    uv = uv_for(t); n = N[t].mean(0); n = n / (np.linalg.norm(n) + 1e-9)
    for j in range(3):
        outP.append(P[t[j]]); outN.append(N[t[j]]); outUV.append(uv[j])
    for j in (0, 2, 1):  # the inside: the same face turned in, a hair inward
        outP.append(P[t[j]] - n * 0.012); outN.append(-N[t[j]]); outUV.append(uv[j])
outP = np.array(outP, np.float32); outN = np.array(outN, np.float32); outUV = np.array(outUV, np.float32)
# the UVs wrap past 1 at the strip's seam: the image repeats across u
COLS = {'pink': (232, 120, 160, 255), 'blue': (62, 112, 200, 255), 'yellow': (242, 200, 62, 255), 'sky': (96, 184, 224, 255), 'red': (210, 70, 100, 255)}
for name, col in COLS.items(): paint(col).save(OUT + f"FerrisCabinTex_{name}.png")
buf = io.BytesIO(); paint(COLS['pink']).save(buf, 'PNG')

def write_glb(dst, name, P, N, UV, png):
    I = np.arange(len(P), dtype=np.uint32)
    blobs = [P.tobytes(), N.tobytes(), UV.tobytes(), I.tobytes(), png]
    views = []; off = 0; data = b''
    for k, bb in enumerate(blobs):
        pad = (-len(bb)) % 4; v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(bb)}
        if k < 3: v['target'] = 34962
        elif k == 3: v['target'] = 34963
        views.append(v); data += bb + b'\0' * pad; off += len(bb) + pad
    js = {'asset': {'version': '2.0', 'generator': 'ohu ferris_cabin_tex'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
          'nodes': [{'mesh': 0, 'name': name}],
          'meshes': [{'name': name, 'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0}]}],
          'materials': [{'name': name + '_mat', 'alphaMode': 'BLEND', 'doubleSided': False,
                         'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0, 'roughnessFactor': 0.5}}],
          'textures': [{'source': 0}], 'images': [{'bufferView': 4, 'mimeType': 'image/png', 'name': name + '_tex'}],
          'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': len(P), 'type': 'VEC3', 'min': P.min(0).tolist(), 'max': P.max(0).tolist()},
                        {'bufferView': 1, 'componentType': 5126, 'count': len(N), 'type': 'VEC3'},
                        {'bufferView': 2, 'componentType': 5126, 'count': len(UV), 'type': 'VEC2'},
                        {'bufferView': 3, 'componentType': 5125, 'count': len(I), 'type': 'SCALAR'}],
          'bufferViews': views, 'buffers': [{'byteLength': len(data)}]}
    j = json.dumps(js).encode(); j += b' ' * ((-len(j)) % 4)
    open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(data)) + struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(data), 0x004E4942) + data)

write_glb(OUT + "FerrisCabinTex.glb", "FerrisCabinTex", outP, outN, outUV, buf.getvalue())
print("cabin", len(outP) // 3, "tris; bounds", outP.min(0).round(3).tolist(), outP.max(0).round(3).tolist())
