# (D-2010) The mini Santas of the Santa hunt, modelled in Blender like the user's reference photo
# (2026-11-22: small glossy resin Santas: a round red body, a big white beard over the chest, a tiny
# face with bead eyes and a round nose, a floppy hat with a white band and pompom, black boots,
# red mitten arms; poses: hugging, arms up, holding a gift).
#
#   "D:/Blender 5.2/blender.exe" -b -P tools/art/santa/santa_build.py -- <outdir> [look ...]
#
# Writes <outdir>/<look>.glb (one object per colour, so the Roblox importer gives one MeshPart per
# colour, coloured by its material) and <outdir>/<look>.png (a 512 px preview render).
# Units: 1 Blender unit = 1 stud at import time is not assumed; SantaFactory scales the imported
# model to the configured height.
import bpy, math, sys, os
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(os.path.dirname(__file__), "out")
ONLY = set(argv[1:])
os.makedirs(OUT, exist_ok=True)

COL = {
    "red": (0.78, 0.04, 0.06), "white": (0.95, 0.95, 0.95), "skin": (0.96, 0.74, 0.6), "black": (0.02, 0.02, 0.025),
    "nose": (0.95, 0.6, 0.55), "gold": (0.95, 0.68, 0.12), "green": (0.1, 0.45, 0.2), "brown": (0.35, 0.2, 0.1),
    "pink": (1.0, 0.55, 0.68), "sky": (0.55, 0.78, 1.0), "blue": (0.15, 0.35, 0.85), "navy": (0.05, 0.1, 0.35),
    "grey": (0.6, 0.6, 0.65), "yellow": (1.0, 0.8, 0.15), "teal": (0.2, 0.75, 0.8), "cream": (0.95, 0.88, 0.7),
    "bread": (0.82, 0.55, 0.25), "deer": (0.55, 0.34, 0.18), "rednose": (1.0, 0.05, 0.05), "orange": (1.0, 0.5, 0.15),
}
MATS = {}


def mat(name):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    c = COL[name]
    bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
    bsdf.inputs["Roughness"].default_value = 0.22
    m.diffuse_color = (c[0], c[1], c[2], 1)
    MATS[name] = m
    return m


def finish(obj, color, subdiv=2, smooth=True):
    obj.data.materials.clear()
    obj.data.materials.append(mat(color))
    obj["col"] = color
    if subdiv:
        mod = obj.modifiers.new("sub", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def sphere(loc, scale, color, rot=(0, 0, 0), seg=16, sub=1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return finish(o, color, sub)


def cyl(loc, radius, depth, color, rot=(0, 0, 0), verts=24, sub=0, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    if bevel:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = 3
    return finish(o, color, sub)


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


def limb(a, b, r, color):
    """a capsule from a to b (an arm)"""
    a, b = Vector(a), Vector(b)
    d = b - a
    mid = (a + b) / 2
    rot = d.to_track_quat("Z", "Y").to_euler()
    cyl(mid, r, d.length, color, rot=rot, verts=16)
    sphere(a, (r, r, r), color, seg=12, sub=0)
    return sphere(b, (r * 1.15, r * 1.15, r * 1.15), color, seg=12, sub=0)  # the mitten


# The base Santa (about 2.6 units tall, facing -Y, standing on z = 0).
# pose: "hug" (arms round the belly), "up" (arms up and out), "hold" (both hands forward at chest height)
def santa(suit="red", trim="white", hat="santa", pose="hug", hatcol=None, mitten=None):
    sphere((0, 0, 0.95), (0.95, 0.82, 0.95), suit)                    # body
    sphere((0, 0.02, 0.32), (0.9, 0.78, 0.38), suit)                   # hips
    for s in (-1, 1):
        sphere((0.34 * s, -0.22, 0.15), (0.3, 0.45, 0.2), "black")     # boots
    sphere((0, 0, 1.95), (0.6, 0.56, 0.58), "skin")                    # head
    sphere((0, -0.3, 1.4), (0.72, 0.46, 0.56), "white")                # beard (over the chest)
    sphere((0, -0.42, 1.12), (0.56, 0.34, 0.42), "white")
    for s in (-1, 1):
        sphere((0.18 * s, -0.57, 1.82), (0.22, 0.13, 0.11), "white", rot=(0, math.radians(18 * s), 0))  # moustache
        sphere((0.17 * s, -0.55, 2.03), (0.05, 0.03, 0.06), "black", seg=10, sub=0)                 # eyes
        sphere((0.33 * s, -0.48, 1.92), (0.08, 0.03, 0.05), "pink", seg=10, sub=0)                   # cheeks
    sphere((0, -0.63, 1.92), (0.09, 0.085, 0.08), "nose", seg=12, sub=0)
    hc = hatcol or "red"
    if hat == "santa":
        sphere((0, 0.02, 2.3), (0.6, 0.57, 0.4), hc)                 # the hat over the top of the head
        torus((0, 0, 2.26), 0.57, 0.13, trim)                          # fur band on the forehead
        # the floppy tip: a cone leaning to the side, the pompom at its end
        ang = math.radians(62)
        base = Vector((0.12, 0.08, 2.52))
        d = Vector((math.sin(ang), 0, math.cos(ang)))
        cone(base + d * 0.42, 0.42, 0.06, 0.84, hc, rot=(0, ang, 0))
        sphere(base + d * 0.9, (0.17, 0.17, 0.17), trim)
    m = mitten or suit
    if pose == "hug":
        for s in (-1, 1):
            limb((0.8 * s, -0.05, 1.25), (0.6 * s, -0.55, 0.85), 0.2, suit)
    elif pose == "up":
        for s in (-1, 1):
            limb((0.8 * s, -0.05, 1.3), (1.25 * s, -0.25, 1.95), 0.2, suit)
    elif pose == "hold":
        for s in (-1, 1):
            limb((0.8 * s, -0.05, 1.25), (0.38 * s, -0.8, 1.05), 0.2, suit)
    HAND = {"hug": (0, -0.75, 0.85), "up": (1.25, -0.25, 2.1), "hold": (0, -0.95, 1.12)}[pose]
    return Vector(HAND)


def gat(trim):
    cyl((0, 0, 2.32), 0.95, 0.05, "black")
    cyl((0, 0, 2.6), 0.33, 0.55, "black", bevel=0.05)


LOOKS = {}
def look(name):
    def deco(fn):
        LOOKS[name] = fn
        return fn
    return deco


@look("classic")
def _():
    santa(pose="hug")

@look("golden")
def _():
    for k in ("red",):
        pass
    santa(suit="gold", trim="cream", hatcol="gold", pose="up")
    sphere((0, 0.42, 3.25), (0.16, 0.05, 0.16), "yellow")

@look("dj")
def _():
    santa(pose="up")
    torus((0, 0.0, 2.05), 0.66, 0.05, "black", rot=(math.radians(90), 0, math.radians(90)))
    for s in (-1, 1):
        cyl((0.66 * s, 0, 2.0), 0.2, 0.16, "black", rot=(0, math.radians(90), 0), bevel=0.04)
    torus((0, -0.62, 1.15), 0.28, 0.035, "gold", rot=(math.radians(70), 0, 0))

@look("barista")
def _():
    h = santa(pose="hold")
    box((0, -0.7, 0.75), (0.95, 0.08, 0.8), "brown")
    cyl(h + Vector((0, -0.05, 0.12)), 0.16, 0.34, "white", bevel=0.03)
    cyl(h + Vector((0, -0.05, 0.31)), 0.17, 0.05, "brown")

@look("camera")
def _():
    h = santa(pose="hold")
    box(h + Vector((0, -0.05, 0.12)), (0.55, 0.3, 0.38), "pink", bevel=0.06)
    cyl(h + Vector((0, -0.25, 0.12)), 0.13, 0.15, "black", rot=(math.radians(90), 0, 0))

@look("store")
def _():
    h = santa(hat="cap", pose="hold")
    sphere((0, 0.05, 2.32), (0.62, 0.6, 0.32), "green")
    box((0, -0.55, 2.28), (0.55, 0.4, 0.06), "green")
    box(h + Vector((0, -0.05, 0.2)), (0.4, 0.14, 0.52), "yellow", bevel=0.05)

@look("gukbap")
def _():
    h = santa(pose="hold")
    cyl(h + Vector((0, -0.05, 0.1)), 0.32, 0.22, "black", bevel=0.05)
    cyl(h + Vector((0, -0.05, 0.2)), 0.28, 0.03, "cream")

@look("hanbok")
def _():
    santa(suit="pink", trim="sky", hat="none", pose="hug")
    gat("black")
    box((0, -0.82, 1.05), (0.12, 0.05, 0.5), "sky")

@look("guard")
def _():
    santa(suit="red", trim="navy", hat="none", pose="hold")
    cyl((0, 0, 2.32), 0.8, 0.06, "black")
    cyl((0, 0, 2.55), 0.4, 0.45, "black", bevel=0.05)
    sphere((0.3, 0, 2.95), (0.1, 0.1, 0.3), "red")
    cyl((0.55, -0.78, 1.4), 0.04, 1.6, "brown")

@look("teacup")
def _():
    santa(pose="up")
    cyl((0, 0, 0.55), 1.15, 1.0, "sky", verts=32, bevel=0.06)
    torus((0, 0, 1.05), 1.15, 0.07, "white")
    torus((1.25, 0, 0.6), 0.3, 0.06, "sky", rot=(math.radians(90), 0, 0))

@look("surfer")
def _():
    santa(pose="up")
    box((0, -0.62, 2.05), (0.62, 0.06, 0.13), "black")
    box((1.35, 0.35, 1.2), (0.6, 0.12, 2.4), "teal", rot=(0, math.radians(-8), 0), bevel=0.25)

@look("baker")
def _():
    h = santa(hat="none", pose="hold")
    cyl((0, 0, 2.38), 0.5, 0.3, "white")
    sphere((0, 0, 2.75), (0.62, 0.62, 0.38), "white")
    sphere(h + Vector((0, -0.05, 0.15)), (0.32, 0.2, 0.18), "bread")

@look("bus")
def _():
    h = santa(suit="blue", hat="none", pose="hold")
    sphere((0, 0.05, 2.32), (0.62, 0.6, 0.32), "navy")
    box((0, -0.55, 2.28), (0.55, 0.4, 0.06), "navy")
    box(h + Vector((0, -0.05, 0.45)), (0.5, 0.06, 0.34), "green")
    cyl(h + Vector((0, -0.05, 0.1)), 0.03, 0.5, "grey")

@look("subway")
def _():
    h = santa(pose="hold")
    torus((0, -0.05, 1.42), 0.55, 0.12, "green")
    box(h + Vector((0, -0.05, 0.25)), (0.4, 0.04, 0.26), "green", bevel=0.02)

@look("wheel")
def _():
    santa(pose="up")
    cyl((1.25, -0.25, 2.75), 0.015, 1.3, "white")
    sphere((1.25, -0.25, 3.55), (0.32, 0.32, 0.38), "pink")

@look("bumper")
def _():
    santa(pose="up")
    box((0, 0, 0.35), (2.2, 2.3, 0.7), "yellow", bevel=0.2)
    torus((0, 0, 0.3), 1.2, 0.18, "black")

@look("churros")
def _():
    h = santa(pose="hold")
    cyl(h + Vector((0.1, -0.05, 0.35)), 0.08, 0.9, "bread", rot=(0, math.radians(20), 0), verts=8)

@look("vip")
def _():
    santa(suit="black", trim="gold", hatcol="black", pose="hug")
    box((0, -0.62, 2.05), (0.62, 0.06, 0.13), "black")
    torus((0, -0.62, 1.15), 0.28, 0.035, "gold", rot=(math.radians(70), 0, 0))

@look("viking")
def _():
    santa(hat="none", pose="up")
    sphere((0, 0, 2.3), (0.66, 0.62, 0.45), "grey")
    for s in (-1, 1):
        cone((0.7 * s, 0, 2.65), 0.12, 0.02, 0.6, "cream", rot=(0, math.radians(-30 * s), 0))

@look("rudolph")
def _():
    santa(pose="hug")
    o = Vector((-1.6, 0.2, 0))
    sphere(o + Vector((0, 0, 0.85)), (0.55, 0.75, 0.5), "deer")
    sphere(o + Vector((0, -0.6, 1.5)), (0.38, 0.4, 0.38), "deer")
    sphere(o + Vector((0, -0.98, 1.45)), (0.12, 0.12, 0.12), "rednose")
    for s in (-1, 1):
        sphere(o + Vector((0.14 * s, -0.9, 1.6)), (0.04, 0.03, 0.04), "black", seg=10, sub=0)
        cyl(o + Vector((0.2 * s, -0.5, 2.0)), 0.04, 0.5, "brown", rot=(0, math.radians(25 * s), 0))
        for z in (-0.4, 0.4):
            cyl(o + Vector((0.25 * s, z, 0.25)), 0.09, 0.5, "deer")

for name in list(LOOKS):
    if ONLY and name not in ONLY:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    LOOKS[name]()
    # export: apply modifiers, one object per colour (join by material colour)
    bpy.ops.object.select_all(action="SELECT")
    for o in bpy.context.selected_objects:
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    groups = {}
    for o in bpy.context.scene.objects:
        groups.setdefault(o.get("col"), []).append(o)
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
    # preview render
    scn = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("cam", cam_data)
    scn.collection.objects.link(cam)
    cam.location = (3.2, -8.5, 3.0)
    direction = Vector((0, 0, 1.4)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
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
    scn.view_settings.view_transform = "Standard"
    scn.world = world
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scn.render.engine = eng
            break
        except Exception:
            pass
    scn.render.resolution_x = 512
    scn.render.resolution_y = 512
    scn.render.film_transparent = False
    scn.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SANTA", name)
