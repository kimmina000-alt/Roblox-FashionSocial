# (D-2042) The Santa album's card pictures: each Santa (.blend from santa_from_base.py, the smooth v3)
# rendered on a transparent background, 512 x 512, from the front a little to the side, framed to fit
# (wide ones like Rudolph, the teacup and the bumper car included).
#   "D:/Blender 5.2/blender.exe" -b -P tools/art/santa/album_render.py -- <blenddir> <outdir> [look ...]
import bpy, sys, os, glob
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = set(argv[2:])
os.makedirs(OUT, exist_ok=True)

for path in sorted(glob.glob(os.path.join(SRC, "*.blend"))):
    name = os.path.splitext(os.path.basename(path))[0]
    if (ONLY and name not in ONLY) or name.startswith("base"):
        continue
    bpy.ops.wm.open_mainfile(filepath=path)
    scn = bpy.context.scene
    for o in list(scn.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o)
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in scn.objects:
        if o.type == "MESH":
            me = o.evaluated_get(dg).to_mesh()
            pts += [o.matrix_world @ v.co for v in me.vertices]
            o.evaluated_get(dg).to_mesh_clear()
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (mn + mx) / 2
    size = max(mx.x - mn.x, mx.z - mn.z) * 1.12
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = size
    cam = bpy.data.objects.new("cam", cam_data)
    scn.collection.objects.link(cam)
    d = Vector((0.3, -1.0, 0.22)).normalized()
    cam.location = ctr + d * 20
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
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
    scn.render.film_transparent = True
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.render.resolution_x = 512
    scn.render.resolution_y = 512
    scn.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("ALBUM", name)
