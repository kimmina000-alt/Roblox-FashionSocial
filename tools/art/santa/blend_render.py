# (D-2012) Render a Santa .blend the same way as santa_build.py's preview and list its objects
# (to compare the user's hand edits with the generated file).
#   "D:/Blender 5.2/blender.exe" -b <file.blend> -P tools/art/santa/blend_render.py -- <out.png> [front]
import bpy, sys, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
front = len(argv) > 1 and argv[1] == "front"
scn = bpy.context.scene

info = []
for o in scn.objects:
    if o.type != "MESH":
        continue
    mats = [m.name for m in o.data.materials if m]
    info.append({"name": o.name, "mat": mats, "loc": [round(v, 3) for v in o.location],
                 "rot": [round(v, 3) for v in o.rotation_euler], "scale": [round(v, 3) for v in o.scale],
                 "dims": [round(v, 3) for v in o.dimensions], "verts": len(o.data.vertices),
                 "mods": [m.type + ":" + str(getattr(m, "levels", "")) for m in o.modifiers]})
print("OBJECTS " + json.dumps(info, ensure_ascii=False))

for o in list(scn.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 70
cam = bpy.data.objects.new("cam", cam_data)
scn.collection.objects.link(cam)
cam.location = (0.6, -9.5, 3.4) if front else (3.2, -8.5, 3.0)
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
scn.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
