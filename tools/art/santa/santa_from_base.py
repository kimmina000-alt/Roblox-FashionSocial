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
    "ivory": (1.0, 0.95, 0.82),
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


def sphere(loc, scale, color, rot=(0, 0, 0), sub=1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=loc, rotation=rot)
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
        if not any(m.type == "SUBSURF" for m in o.modifiers):
            small = max(o.dimensions) < 0.3
            mod = o.modifiers.new("sub", "SUBSURF")
            mod.levels = 1 if small else 2
            mod.render_levels = mod.levels
        else:
            for m in o.modifiers:
                if m.type == "SUBSURF" and max(o.dimensions) >= 0.3:
                    m.levels = 2
                    m.render_levels = 2
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
    cyl(RHAND + Vector((0, -0.12, 0.18)), 0.17, 0.36, "white", bevel=0.03)
    cyl(RHAND + Vector((0, -0.12, 0.38)), 0.18, 0.05, "brown")

@look("camera")
def _(hat):
    box(RHAND + Vector((-0.1, -0.18, 0.15)), (0.55, 0.3, 0.38), "pink", bevel=0.06)
    cyl(RHAND + Vector((-0.1, -0.38, 0.15)), 0.13, 0.15, "black", rot=(math.radians(90), 0, 0))

@look("store")
def _(hat):
    remove_hat(hat)
    capdome("green", "green")
    box(RHAND + Vector((0, -0.15, 0.25)), (0.4, 0.14, 0.52), "yellow", bevel=0.05)

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
    box(RHAND + Vector((0, -0.15, 0.28)), (0.42, 0.04, 0.27), "green", bevel=0.02)
    for s in (-1, 1):
        sphere((0.62 * s, 0, 1.98), (0.18, 0.22, 0.22), "green")   # earmuffs

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

@look("rudolph")
def _(hat):
    o = Vector((-1.9, 0.2, 0))
    sphere(o + Vector((0, 0, 0.85)), (0.55, 0.75, 0.5), "deer")
    sphere(o + Vector((0, -0.6, 1.5)), (0.38, 0.4, 0.38), "deer")
    sphere(o + Vector((0, -0.98, 1.45)), (0.12, 0.12, 0.12), "rednose")
    for s in (-1, 1):
        sphere(o + Vector((0.14 * s, -0.9, 1.6)), (0.04, 0.03, 0.04), "black", sub=0)
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
