# (D-1347, user 2026-11-13: "최적화 작업") A light copy of the 8-stud giwa wall module of
# build_hongdae_layout.lua (giwaModule, D-143): the same pieces at the same places, built
# here with few-sided cylinders and without faces nobody sees, so one module is about
# 2,000 triangles instead of the CSG union's 11,092 (450 of them on the 한옥 walls).
# Run: "D:\Blender 5.2\blender.exe" -b --python tools/art/giwa_lite/make_giwa_lite.py
# Output: tools/art/giwa_lite/GiwaLite.glb (Roblox frame: X along the wall, Y up).
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "GiwaLite.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()

def frame(pos, right, up):
    right = Vector(right).normalized(); up = Vector(up).normalized()
    back = right.cross(up)  # Roblox CFrame.fromMatrix: Z = X cross Y
    return Matrix(((right.x, up.x, back.x, pos[0]), (right.y, up.y, back.y, pos[1]),
                   (right.z, up.z, back.z, pos[2]), (0, 0, 0, 1)))

def box(size, m, faces=None):
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = [bm.verts.new(m @ Vector((x * sx, y * sy, z * sz))) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    quads = {"-x": (0, 1, 3, 2), "+x": (4, 6, 7, 5), "-y": (0, 4, 5, 1), "+y": (2, 3, 7, 6), "-z": (0, 2, 6, 4), "+z": (1, 5, 7, 3)}
    for k, q in quads.items():
        if faces is None or k in faces:
            bm.faces.new([vs[i] for i in q])

def cyl(length, diam, m, seg, caps=("-", "+")):
    # Roblox cylinder: axis along the part's X
    r, h = diam / 2, length / 2
    rings = []
    for sx in (-h, h):
        rings.append([bm.verts.new(m @ Vector((sx, r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg)))) for i in range(seg)])
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new([rings[0][i], rings[0][j], rings[1][j], rings[1][i]])
    if "-" in caps: bm.faces.new(list(reversed(rings[0])))
    if "+" in caps: bm.faces.new(rings[1])

def wedge_side(s, BASE, RISE, RUN, LEN):
    # triangular prism: high along the ridge, down to the eave on side s
    h = LEN / 2
    p = [(0, BASE), (0, BASE + RISE), (s * RUN, BASE)]
    a = [bm.verts.new(Vector((-h, y, z))) for z, y in p]
    b = [bm.verts.new(Vector((h, y, z))) for z, y in p]
    f = [a[1], b[1], b[2], a[2]]  # the slope (the only face seen), facing up
    bm.faces.new(f if s < 0 else list(reversed(f)))

LEN, BASE, RISE, RUN = 8.0, 0.25, 0.8, 1.75
box((LEN, BASE, 2 * RUN), Matrix.Translation((0, BASE / 2, 0)), faces={"+x", "-x", "-y", "+z", "-z"})
L = math.sqrt(RUN * RUN + RISE * RISE)
for s in (-1, 1):
    wedge_side(s, BASE, RISE, RUN, LEN)
    d = Vector((0, -RISE, s * RUN)).normalized()
    nrm = Vector((0, RUN, s * RISE)).normalized()
    midS = Vector((0, BASE + RISE / 2, s * RUN / 2))
    PITCH = LEN / 10
    for i in range(10):
        x = -LEN / 2 + PITCH * (i + 0.5)
        c = midS + Vector((x, 0, 0)) + nrm * 0.12 + d * 0.1
        cyl(L + 0.2, 0.34, frame(c, d, nrm), 8, caps=())  # cover tile (its ends are hidden)
        e = c + d * ((L + 0.2) / 2 + 0.04)
        cyl(0.08, 0.46, frame(e, d, nrm), 10, caps=("+",))  # end cap 수막새
        cyl(0.05, 0.3, frame(e + d * 0.06, d, nrm), 8, caps=("+",))  # its raised centre
        xm = x + PITCH / 2
        if xm < LEN / 2 - 0.01:
            box((0.5, 0.06, 0.22), frame(midS + Vector((xm, 0, 0)) + d * (L / 2 - 0.05) + nrm * 0.02, (1, 0, 0), nrm), faces={"+y", "+z", "-z"})
    eave = Vector((0, BASE - 0.12, s * (RUN + 0.02)))
    for i in range(11):
        x = -LEN / 2 + PITCH * i
        w = PITCH / 2 - 0.04 if i in (0, 10) else PITCH - 0.08
        xc = x + w / 2 if i == 0 else (x - w / 2 if i == 10 else x)
        up = Vector((0, 1, -s * 0.5)).normalized()
        box((w, 0.42, 0.07), frame(eave + Vector((xc, 0, 0)), (1, 0, 0), up), faces={"+z", "-z", "-y", "-x", "+x"})
        cyl(0.07, w * 0.72, frame(eave + Vector((xc, -0.13, s * 0.07)), (0, 0, s), (0, 1, 0)), 8, caps=("+", "-"))
top = BASE + RISE
for sz, y in (((LEN, 0.24, 1.2), top + 0.06), ((LEN, 0.2, 0.86), top + 0.26), ((LEN, 0.2, 0.64), top + 0.46), ((LEN, 0.16, 0.42), top + 0.64)):
    box(sz, Matrix.Translation((0, y, 0)), faces={"+y", "+z", "-z", "+x", "-x"})

# (faces are wound outward by construction: no normal recalculation on this open mesh)
bmesh.ops.triangulate(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("GiwaLite")
bm.to_mesh(mesh)
print("GIWA triangles:", len(bm.faces))
bm.free()
# Roblox frame (Y up) -> Blender (Z up): the glTF exporter turns Y-up back
for v in mesh.vertices:
    x, y, z = v.co
    v.co = Vector((x, -z, y))
obj = bpy.data.objects.new("GiwaLite", mesh)
bpy.context.scene.collection.objects.link(obj)
matl = bpy.data.materials.new("Giwa")
matl.diffuse_color = (64 / 255, 68 / 255, 72 / 255, 1)
mesh.materials.append(matl)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_yup=True)
print("wrote", OUT)
