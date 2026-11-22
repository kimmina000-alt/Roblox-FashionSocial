# (D-2011) The middle Santa of the user's reference photo only (arms up, legs spread), modelled as
# close to it as possible. Helpers copied from santa_build.py.
#   "D:/Blender 5.2/blender.exe" -b -P tools/art/santa/santa_star.py -- <outdir>
#
# (from santa_build.py:) The mini Santas of the Santa hunt, modelled in Blender like the user's reference photo
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



def star():
    sphere((0, 0, 1.08), (0.82, 0.7, 0.72), "red")                     # chest / belly
    sphere((0, 0.02, 0.6), (0.78, 0.62, 0.42), "red")                   # hips
    for s in (-1, 1):
        limb((0.38 * s, -0.05, 0.55), (0.98 * s, -0.2, 0.26), 0.25, "red")        # legs spread wide
        sphere((1.2 * s, -0.26, 0.17), (0.42, 0.3, 0.22), "black", rot=(0, 0, math.radians(-10 * s)))  # boots pointing out
        limb((0.62 * s, -0.02, 1.38), (1.15 * s, -0.3, 1.95), 0.26, "red")        # arms up and out
    sphere((0, 0, 1.95), (0.56, 0.52, 0.54), "skin")                   # head
    sphere((0, -0.3, 1.45), (0.74, 0.44, 0.56), "white")                 # beard over the chest
    for x in (-0.4, -0.14, 0.14, 0.4):
        sphere((x, -0.42, 1.1), (0.3, 0.26, 0.22), "white")              # the beard's round bottom edge
    for s in (-1, 1):
        sphere((0.19 * s, -0.52, 1.78), (0.24, 0.14, 0.12), "white", rot=(0, math.radians(15 * s), 0))  # moustache
        sphere((0.15 * s, -0.5, 2.0), (0.045, 0.03, 0.055), "black", seg=10, sub=0)                     # eyes
        sphere((0.3 * s, -0.44, 1.9), (0.07, 0.03, 0.045), "pink", seg=10, sub=0)                      # cheeks
    sphere((0, -0.58, 1.88), (0.08, 0.075, 0.07), "nose", seg=12, sub=0)
    # the hat: a red dome on the head, a white band, a short tip leaning back, the pompom on top
    sphere((0, 0.03, 2.26), (0.56, 0.54, 0.4), "red")
    torus((0, 0, 2.2), 0.54, 0.13, "white")
    ang = math.radians(-18)
    cone((0, 0.1, 2.68), 0.36, 0.05, 0.62, "red", rot=(ang, 0, 0))
    sphere((0, 0.2, 3.0), (0.17, 0.17, 0.17), "white")


bpy.ops.wm.read_factory_settings(use_empty=True)
MATS.clear()
star()
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
    bpy.context.active_object.name = f"star_{col}"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "star.glb"), export_format="GLB", use_selection=True, export_apply=True)
# preview render
scn = bpy.context.scene
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 70
cam = bpy.data.objects.new("cam", cam_data)
scn.collection.objects.link(cam)
cam.location = (0.6, -9.5, 3.4)
direction = Vector((0, 0, 1.35)) - cam.location
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
scn.render.filepath = os.path.join(OUT, "star.png")
bpy.ops.render.render(write_still=True)
print("SANTA star")
