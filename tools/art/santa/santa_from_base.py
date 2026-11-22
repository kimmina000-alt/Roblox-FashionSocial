# (D-2013) The 20 mini Santas again, on the user's own Santa (their hand edit of classic.blend,
# 2026-11-22: one big beard from the lower face to the belly, a tall cap with a low white band whose
# tip and pompom hang down the back, a plain round body, short arms at the beard's sides, mirrored
# boots). user: "응 매끈하게 해서 그걸로 19명 다시 만들어".
#
#   "D:/Blender 5.2/blender.exe" -b -P tools/art/santa/santa_from_base.py -- <base.blend> <outdir> [look ...]
#
# Per look: the base is opened (never saved over), made smooth (Subdivision 2 on the shapes that had
# none, the beard / moustache get the white material they lacked), the look's colours and props are
# added, then <outdir>/blend/<look>.blend (editable), <outdir>/<look>.glb (one object per colour) and
# <outdir>/<look>.png (preview) are written.
import bpy, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, OUT = argv[0], argv[1]
ONLY = set(argv[2:])
os.makedirs(os.path.join(OUT, "blend"), exist_ok=True)

COL = {
    "red": (0.78, 0.04, 0.06), "white": (0.95, 0.95, 0.95), "skin": (0.96, 0.74, 0.6), "black": (0.02, 0.02, 0.025),
    "nose": (0.95, 0.6, 0.55), "gold": (0.83, 0.55, 0.08), "green": (0.1, 0.45, 0.2), "brown": (0.35, 0.2, 0.1),
    "pink": (1.0, 0.55, 0.68), "sky": (0.55, 0.78, 1.0), "blue": (0.15, 0.35, 0.85), "navy": (0.05, 0.1, 0.35),
    "grey": (0.42, 0.44, 0.5), "yellow": (1.0, 0.8, 0.15), "teal": (0.2, 0.75, 0.8), "cream": (0.95, 0.88, 0.7),
    "bread": (0.82, 0.55, 0.25), "deer": (0.55, 0.34, 0.18), "rednose": (1.0, 0.05, 0.05), "orange": (1.0, 0.5, 0.15),
    "ivory": (1.0, 0.95, 0.82), "darkgreen": (0.02, 0.2, 0.09), "rice": (0.98, 0.97, 0.93), "lightpink": (1.0, 0.6, 0.72), "noodle": (0.96, 0.8, 0.38), "wood": (0.72, 0.5, 0.28), "ramenred": (0.85, 0.08, 0.1), "darkgrey": (0.13, 0.13, 0.15), "leaf": (0.12, 0.5, 0.2),
}

# the base's landmarks (from its bounding boxes)
HEAD = Vector((0, 0, 1.95))
HEAD_TOP = 2.54
FACE_Y = -0.6
EYES_Z = 2.03
RHAND = Vector((0.98, -0.9, 1.05))
LHAND = Vector((-0.98, -0.9, 1.05))


def mat(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
    c = COL[name]
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
        bsdf.inputs["Roughness"].default_value = 0.22
    m.diffuse_color = (c[0], c[1], c[2], 1)
    return m


def recolor(matname, colname):
    """the base's material `matname` gets the colour `colname` (e.g. the suit red → pink)"""
    m = bpy.data.materials.get(matname)
    if not m:
        return
    c = COL[colname]
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
        if colname == "gold":
            bsdf.inputs["Metallic"].default_value = 0.8
    m.diffuse_color = (c[0], c[1], c[2], 1)


def finish(o, color, sub=2):
    o.data.materials.clear()
    o.data.materials.append(mat(color))
    if sub:
        mod = o.modifiers.new("sub", "SUBSURF")
        mod.levels = sub
        mod.render_levels = sub
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def sphere(loc, scale, color, rot=(0, 0, 0), sub=1, seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(4, seg // 2), radius=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return finish(o, color, sub)


def cyl(loc, radius, depth, color, rot=(0, 0, 0), verts=24, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    if bevel:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = 3
    return finish(o, color, 0)


def disc(loc, radius, normal, color, verts=10):
    """(D-2019) a flat round piece facing `normal` (flower petals, badges, eyes): a thin 10-sided cylinder"""
    rot = Vector(normal).normalized().to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=0.012, location=loc, rotation=rot)
    return finish(bpy.context.active_object, color, 0)


def box(loc, size, color, rot=(0, 0, 0), bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    b = o.modifiers.new("bev", "BEVEL")
    b.width = bevel
    b.segments = 3
    return finish(o, color, 0)


def torus(loc, major, minor, color, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot, major_segments=32, minor_segments=12)
    return finish(bpy.context.active_object, color, 0)


def cone(loc, r1, r2, depth, color, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.active_object, color, 0)


def prep_base():
    """smooth the user's Santa and give the material-less shapes white"""
    hat = None
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        if len(o.data.materials) == 0 or all(m is None for m in o.data.materials):
            o.data.materials.clear()
            o.data.materials.append(mat("white"))
        names = [m.name for m in o.data.materials if m]
        if "red" in names and "white" in names:
            hat = o
        if o is not hat and len(o.data.polygons) > 400 and max(o.dimensions) > 1.3 and "red" in names and len(names) == 2:
            hat = o
        # (D-2018, user 2026-11-22: "산타 몸 매끈하지 않아도 됨. 모자도 폴리곤 줄일 수 있으면 줄여") lighter:
        # one Subdivision step on the big shapes, none on the small ones and none on the hat (smooth shading only)
        for m in list(o.modifiers):
            if m.type == "SUBSURF":
                o.modifiers.remove(m)
        small = max(o.dimensions) < 0.3
        if o is not hat and not small:
            mod = o.modifiers.new("sub", "SUBSURF")
            mod.levels = 1
            mod.render_levels = 1
        for p in o.data.polygons:
            p.use_smooth = True
    return hat


def remove_hat(hat):
    """for the looks with their own hat: the cap and the pompom hanging down the back go"""
    for o in list(bpy.context.scene.objects):
        if o == hat or (o.type == "MESH" and o.location.y > 0.9 and o.location.z > 1.5 and max(o.dimensions) < 0.5):
            bpy.data.objects.remove(o)
    # the pompom (a small white ball behind the head)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            vs = [o.matrix_world @ v.co for v in o.data.vertices]
            if vs and min(v.y for v in vs) > 0.9 and max(o.dimensions) < 0.5:
                bpy.data.objects.remove(o)


def suit_only(colname):
    """(D-2016) the suit (body and arms) in another colour, the red hat kept: the red-only shapes that are
    not the hat get their own material"""
    m = mat(colname)
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            names = [x.name for x in o.data.materials if x]
            if names == ["red"]:
                o.data.materials.clear()
                o.data.materials.append(m)


def arms_object():
    best = None
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and [x.name for x in o.data.materials if x] == ["red"] and o.dimensions.x > 2.0 and o.dimensions.z < 1.2:
            best = o
    return best


def raise_arms(lift_deg=60, inward_deg=30):
    """(D-2016) both arms up in front of the face (taking a photo): the arms shape is split into its two
    arms and each turned about its shoulder"""
    from mathutils import Matrix
    arms = arms_object()
    if not arms:
        return
    bpy.ops.object.select_all(action="DESELECT")
    arms.select_set(True)
    bpy.context.view_layer.objects.active = arms
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in list(bpy.context.selected_objects):
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        cx = sum(v.x for v in vs) / len(vs)
        side = 1 if cx > 0 else -1
        pivot = Vector((0.8 * side, -0.1, 1.5))
        rot = Matrix.Rotation(math.radians(-inward_deg * side), 4, "Z") @ Matrix.Rotation(math.radians(-lift_deg), 4, "X")
        M = Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot)
        o.data.transform(o.matrix_world.inverted() @ M @ o.matrix_world)


def capdome(color, visor):
    sphere((0, 0.02, HEAD_TOP - 0.18), (0.64, 0.62, 0.34), color)
    box((0, FACE_Y - 0.05, HEAD_TOP - 0.24), (0.58, 0.42, 0.06), visor)


LOOKS = {}
def look(name):
    def deco(fn):
        LOOKS[name] = fn
        return fn
    return deco


@look("classic")
def _(hat):
    pass

@look("golden")
def _(hat):
    recolor("red", "gold")
    recolor("white", "ivory")
    sphere((0, 0.1, 3.08), (0.18, 0.06, 0.18), "yellow")

@look("dj")
def _(hat):
    for s in (-1, 1):
        cyl((0.74 * s, -0.05, 2.02), 0.27, 0.2, "black", rot=(0, math.radians(90), 0), bevel=0.05)
        cyl((0.85 * s, -0.05, 2.02), 0.18, 0.04, "red", rot=(0, math.radians(90), 0))
    torus((0, -0.05, 2.15), 0.78, 0.06, "black", rot=(math.radians(90), 0, 0))
    torus((0, -0.96, 1.15), 0.3, 0.04, "gold", rot=(math.radians(75), 0, 0))

@look("barista")
def _(hat):
    suit_only("darkgreen")   # (D-2016, user: "옷 몸통 진한 녹색으로")
    cyl(RHAND + Vector((0, -0.12, 0.18)), 0.17, 0.36, "white", bevel=0.03)
    cyl(RHAND + Vector((0, -0.12, 0.38)), 0.18, 0.05, "brown")

@look("camera")
def _(hat):
    # (D-2016, user: "팔 들고 카메라 찍고 있는 모습") both arms up, the camera held at the eyes' height, just under them
    raise_arms(60, 30)
    box((0, -0.98, 1.82), (0.78, 0.3, 0.42), "pink", bevel=0.07)
    cyl((0.16, -1.17, 1.8), 0.15, 0.14, "black", rot=(math.radians(90), 0, 0))
    cyl((0.16, -1.25, 1.8), 0.1, 0.03, "sky", rot=(math.radians(90), 0, 0))
    box((-0.22, -1.0, 2.07), (0.16, 0.12, 0.1), "black", bevel=0.02)

@look("store")
def _(hat):
    remove_hat(hat)
    capdome("green", "green")
    # (D-2017, user: "한 손에는 뚜껑 열린 컵라면 다른 손에는 젓가락") an open cup ramen in the left hand (white cup
    # with a red band, noodles and broth on top, the lid half peeled back), chopsticks in the right hand
    c = LHAND + Vector((0.05, -0.18, 0.3))
    cone(c, 0.24, 0.32, 0.5, "white", rot=(0, 0, 0))
    cone(c + Vector((0, 0, 0.02)), 0.255, 0.3, 0.16, "ramenred")
    cyl(c + Vector((0, 0, 0.24)), 0.29, 0.03, "noodle")
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.33, depth=0.02, location=c + Vector((0, 0.24, 0.42)), rotation=(math.radians(-65), 0, 0))
    finish(bpy.context.active_object, "white", 0)   # the lid, peeled back
    for dx in (-0.04, 0.04):
        cyl(RHAND + Vector((dx - 0.1, -0.22, 0.45)), 0.025, 0.95, "wood", rot=(math.radians(15), math.radians(-25), 0), verts=8)

@look("gukbap")
def _(hat):
    cyl(RHAND + Vector((-0.1, -0.2, 0.12)), 0.32, 0.22, "black", bevel=0.05)
    cyl(RHAND + Vector((-0.1, -0.2, 0.22)), 0.28, 0.03, "cream")

@look("hanbok")
def _(hat):
    remove_hat(hat)
    recolor("red", "pink")
    cyl((0, 0, HEAD_TOP - 0.08), 0.98, 0.05, "black")
    cyl((0, 0, HEAD_TOP + 0.2), 0.33, 0.55, "black", bevel=0.05)
    box((0, -1.02, 0.7), (0.12, 0.05, 0.45), "sky")

@look("guard")
def _(hat):
    remove_hat(hat)
    cyl((0, 0, HEAD_TOP - 0.08), 0.82, 0.06, "black")
    cyl((0, 0, HEAD_TOP + 0.15), 0.4, 0.45, "black", bevel=0.05)
    sphere((0.3, 0, HEAD_TOP + 0.55), (0.1, 0.1, 0.3), "red")
    cyl(RHAND + Vector((0, -0.12, 0.4)), 0.04, 1.6, "brown")

@look("teacup")
def _(hat):
    cyl((0, 0, 0.5), 1.35, 1.0, "sky", verts=32, bevel=0.06)
    torus((0, 0, 1.0), 1.35, 0.08, "white")
    torus((1.45, 0, 0.55), 0.3, 0.07, "sky", rot=(math.radians(90), 0, 0))

@look("surfer")
def _(hat):
    # (D-2017, user: "남방 입혀 꽃무늬, 복잡하면 연핑크") a light pink shirt with little white flowers (yellow middles)
    suit_only("lightpink")
    import random
    rnd = random.Random(7)
    dg = bpy.context.evaluated_depsgraph_get()
    scn = bpy.context.scene
    # flowers where a ray from the front first meets the pink shirt (body and arms)
    # (D-2040, user 2026-11-22: "꽃 크기를 키우고 개수를 줄여 녹색 이파리도 넣어 하와이안 셔츠 느낌으로") fewer, bigger flowers
    # with two long green leaves each, all flat
    from mathutils import Matrix
    spots = []
    for zi, z in enumerate((0.28, 0.66, 1.04, 1.4)):
        for x in (-0.95, -0.45, 0.05, 0.55, 1.0):
            spots.append((x + (0.25 if zi % 2 else 0) + rnd.uniform(-0.06, 0.06), z + rnd.uniform(-0.05, 0.05)))
    for (x, z) in spots:
        hit, loc, nrm, idx, obj, mtx = scn.ray_cast(dg, Vector((x, -4, z)), Vector((0, 1, 0)))
        if not hit or not obj or not obj.data.materials or obj.data.materials[0].name != "lightpink":
            continue
        n = Vector(nrm).normalized()
        p = Vector(loc) + n * 0.02
        t1 = n.cross(Vector((0, 0, 1))).normalized()
        t2 = n.cross(t1).normalized()
        a0 = rnd.uniform(0, 1.2)
        # leaves first (under the flower)
        for k in range(2):
            la = a0 + math.pi * 0.35 + k * math.pi * 0.9
            d = (t1 * math.cos(la) + t2 * math.sin(la)).normalized()
            X, Z = d, n
            Y = Z.cross(X).normalized()
            rot = Matrix((X, Y, Z)).transposed().to_euler()
            bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.13, depth=0.01, location=p + d * 0.2 - n * 0.005, rotation=rot)
            leaf = finish(bpy.context.active_object, "leaf", 0)
            leaf.scale = (1.0, 0.42, 1.0)
        for i in range(5):
            a = a0 + i * 2 * math.pi / 5
            disc(p + (t1 * math.cos(a) + t2 * math.sin(a)) * 0.115, 0.095, n, "white", verts=8)
        disc(p + n * 0.012, 0.06, n, "yellow", verts=8)
    box((0, FACE_Y - 0.03, EYES_Z), (0.62, 0.06, 0.14), "black")
    box((1.5, 0.35, 1.2), (0.6, 0.12, 2.4), "teal", rot=(0, math.radians(-8), 0), bevel=0.25)

@look("baker")
def _(hat):
    remove_hat(hat)
    cyl((0, 0, HEAD_TOP - 0.05), 0.55, 0.3, "white")
    sphere((0, 0, HEAD_TOP + 0.35), (0.66, 0.66, 0.4), "white")
    sphere(RHAND + Vector((0, -0.18, 0.18)), (0.34, 0.21, 0.19), "bread")

@look("bus")
def _(hat):
    remove_hat(hat)
    recolor("red", "blue")
    capdome("navy", "navy")
    box(RHAND + Vector((0, -0.15, 0.5)), (0.5, 0.06, 0.34), "green")
    cyl(RHAND + Vector((0, -0.15, 0.15)), 0.03, 0.5, "grey")

@look("subway")
def _(hat):
    # (D-2016, user: "지하철 산타 더 개성있게") a subway conductor: navy cap with a line-2 green band and a gold
    # badge, a whistle, and a mini subway car (white with a green stripe and windows) held in both hands
    remove_hat(hat)
    capdome("navy", "black")
    torus((0, 0.02, HEAD_TOP - 0.2), 0.62, 0.06, "green")
    disc((0, FACE_Y - 0.07, HEAD_TOP - 0.05), 0.1, (0, -1, 0.15), "gold")   # (D-2019: a flat badge)
    cyl((0.25, -0.98, 1.55), 0.05, 0.25, "gold", rot=(0, math.radians(90), 0))
    car = Vector((0, -1.08, 1.05))
    box(car, (1.75, 0.46, 0.5), "white", bevel=0.12)
    box(car + Vector((0, 0, -0.07)), (1.77, 0.48, 0.09), "green", bevel=0.02)
    for x in (-0.55, -0.18, 0.18, 0.55):
        box(car + Vector((x, -0.235, 0.1)), (0.24, 0.02, 0.15), "black", bevel=0.02)
    for x in (-0.88, 0.88):
        sphere(car + Vector((x, -0.2, -0.13)), (0.05, 0.03, 0.05), "yellow", sub=0)

@look("wheel")
def _(hat):
    cyl(RHAND + Vector((0, -0.12, 0.75)), 0.015, 1.4, "white")
    sphere(RHAND + Vector((0, -0.12, 1.65)), (0.34, 0.34, 0.4), "pink")

@look("bumper")
def _(hat):
    box((0, 0, 0.35), (2.5, 2.6, 0.7), "yellow", bevel=0.22)
    torus((0, 0, 0.3), 1.35, 0.18, "black")

@look("churros")
def _(hat):
    cyl(RHAND + Vector((0.05, -0.15, 0.4)), 0.08, 0.95, "bread", rot=(0, math.radians(20), 0), verts=8)

@look("vip")
def _(hat):
    recolor("red", "black")
    box((0, FACE_Y - 0.03, EYES_Z), (0.62, 0.06, 0.14), "black")
    torus((0, -0.96, 1.15), 0.3, 0.04, "gold", rot=(math.radians(75), 0, 0))

@look("viking")
def _(hat):
    remove_hat(hat)
    sphere((0, 0, HEAD_TOP - 0.15), (0.68, 0.64, 0.45), "grey")
    for s in (-1, 1):
        # (D-2015, user 2026-11-22: "모자에 뿔 떨어짐") each horn starts inside the helmet's side and leans out
        ang = math.radians(40 * s)
        base = Vector((0.52 * s, 0, HEAD_TOP - 0.05))
        d = Vector((math.sin(ang), 0, math.cos(ang)))
        cone(base + d * 0.3, 0.15, 0.02, 0.6, "cream", rot=(0, ang, 0))
    # (D-2017, user: "수염에 세모 두 개로 만든 리본 두 개") two bows on the beard, each two triangles tip to tip
    # (D-2018, user: "리본 크기 조금 줄이고 위 아래로 정렬") smaller, one above the other on the beard's front
    for (y, z) in ((-0.96, 1.58), (-1.04, 1.32)):   # (on the beard's front; a ray cast here was fooled by the first bow)
        ctr = Vector((0, y, z))
        for side in (-1, 1):
            # a flat triangle (3-sided cylinder, axis front-back), its tip pointing to the knot
            cyl(ctr + Vector((0.12 * side, 0, 0)), 0.14, 0.06, "darkgrey", rot=(math.radians(90), math.radians(-90 if side > 0 else 90), 0), verts=3, bevel=0.02)
        # (D-2019, user: "리본 가운데 동그라미 삭제") no knot ball

@look("rudolph")
def _(hat):
    o = Vector((-1.9, 0.2, 0))
    sphere(o + Vector((0, 0, 0.85)), (0.55, 0.75, 0.5), "deer")
    sphere(o + Vector((0, -0.6, 1.5)), (0.38, 0.4, 0.38), "deer")
    sphere(o + Vector((0, -0.98, 1.45)), (0.12, 0.12, 0.12), "rednose")
    for s in (-1, 1):
        disc(o + Vector((0.14 * s, -0.93, 1.6)), 0.045, (0.25 * s, -1, 0.1), "black")   # (D-2019: flat eyes)
        cyl(o + Vector((0.2 * s, -0.5, 2.0)), 0.04, 0.5, "brown", rot=(0, math.radians(25 * s), 0))
        for z in (-0.4, 0.4):
            cyl(o + Vector((0.25 * s, z, 0.25)), 0.09, 0.5, "deer")


def export(name):
    # an editable copy first (modifiers kept)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "blend", name + ".blend"), copy=True)
    for o in list(bpy.context.scene.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="SELECT")
    for o in list(bpy.context.selected_objects):
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except Exception:
                o.modifiers.remove(m)
    # one object per material (the hat holds red + white)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and len(o.data.materials) > 1:
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.separate(type="MATERIAL")
            bpy.ops.object.mode_set(mode="OBJECT")
    groups = {}
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.data.materials:
            groups.setdefault(o.data.materials[0].name, []).append(o)
    for col, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        bpy.context.active_object.name = f"{name}_{col}"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
    # preview
    scn = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("cam", cam_data)
    scn.collection.objects.link(cam)
    cam.location = (3.2, -8.5, 3.0)
    cam.rotation_euler = (Vector((0, 0, 1.4)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    for loc, energy in (((4, -5, 6), 900), ((-5, -3, 3), 300), ((0, 5, 5), 300)):
        ld = bpy.data.lights.new("l", "AREA")
        ld.energy = energy
        ld.size = 4
        lo = bpy.data.objects.new("l", ld)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scn.collection.objects.link(lo)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    scn.world = world
    scn.view_settings.view_transform = "Standard"
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scn.render.engine = eng
            break
        except Exception:
            pass
    scn.render.resolution_x = 512
    scn.render.resolution_y = 512
    scn.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SANTA", name)


for name in list(LOOKS):
    if ONLY and name not in ONLY:
        continue
    bpy.ops.wm.open_mainfile(filepath=BASE)
    hat = prep_base()
    LOOKS[name](hat)
    export(name)
