r"""
Blender batch tool: DeepMotion/Mixamo-style FBX bone names -> Roblox R15 bone names.

Usage (Windows example, run from a terminal):
  "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --python rename_bones_for_roblox.py -- "C:\in" "C:\out"

For every .fbx in the input folder:
  1. imports it into an empty scene
  2. renames bones (and matching vertex groups and F-curve paths) using MAP
  3. exports the armature + animation to the output folder as <name>_R15.fbx

Bones not in MAP keep their names (spine_JNT, spine1_JNT, neck_JNT, shoulders, fingers).
Edit MAP if the source skeleton uses other names.
"""
import bpy
import glob
import os
import sys

MAP = {
    "hips_JNT": "LowerTorso",
    "spine2_JNT": "UpperTorso",
    "head_JNT": "Head",
    "l_arm_JNT": "LeftUpperArm",
    "l_forearm_JNT": "LeftLowerArm",
    "l_hand_JNT": "LeftHand",
    "r_arm_JNT": "RightUpperArm",
    "r_forearm_JNT": "RightLowerArm",
    "r_hand_JNT": "RightHand",
    "l_upleg_JNT": "LeftUpperLeg",
    "l_leg_JNT": "LeftLowerLeg",
    "l_foot_JNT": "LeftFoot",
    "l_toebase_JNT": "LeftToeBase",
    "r_upleg_JNT": "RightUpperLeg",
    "r_leg_JNT": "RightLowerLeg",
    "r_foot_JNT": "RightFoot",
    "r_toebase_JNT": "RightToeBase",
}


def script_args():
    if "--" not in sys.argv:
        raise SystemExit("usage: blender -b --python rename_bones_for_roblox.py -- <input_dir> <output_dir>")
    args = sys.argv[sys.argv.index("--") + 1:]
    if len(args) != 2:
        raise SystemExit("need <input_dir> <output_dir>")
    return args[0], args[1]


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def iter_fcurves(action):
    """F-curves of an action. Blender 4.x: action.fcurves. Blender 5.x: layers -> strips -> channelbags."""
    if hasattr(action, "fcurves"):
        yield from action.fcurves
        return
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in getattr(strip, "channelbags", []):
                yield from channelbag.fcurves


def rename_all(armature):
    old_to_new = {}
    for bone in armature.data.bones:
        if bone.name in MAP:
            old_to_new[bone.name] = MAP[bone.name]

    # Vertex groups on every mesh that uses this armature
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            for vg in obj.vertex_groups:
                if vg.name in old_to_new:
                    vg.name = old_to_new[vg.name]

    # Animation F-curves refer to bones by name, so their paths must change too
    for action in bpy.data.actions:
        for fc in iter_fcurves(action):
            for old, new in old_to_new.items():
                token = f'pose.bones["{old}"]'
                if token in fc.data_path:
                    fc.data_path = fc.data_path.replace(token, f'pose.bones["{new}"]')

    # Bones last
    for bone in armature.data.bones:
        if bone.name in old_to_new:
            bone.name = old_to_new[bone.name]

    missing = [old for old in MAP if old not in old_to_new]
    return old_to_new, missing


def process(path, out_dir):
    reset_scene()
    bpy.ops.import_scene.fbx(filepath=path)

    armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not armatures:
        print(f"[skip] no armature: {path}")
        return
    armature = armatures[0]

    renamed, missing = rename_all(armature)
    print(f"[{os.path.basename(path)}] renamed {len(renamed)} bones")
    if missing:
        print(f"  not found in this file: {', '.join(missing)}")

    # Export only the armature (with animation); the mesh is not needed for Roblox animation
    for o in bpy.context.view_layer.objects:
        o.select_set(o == armature)
    bpy.context.view_layer.objects.active = armature

    base = os.path.splitext(os.path.basename(path))[0]
    out_path = os.path.join(out_dir, f"{base}_R15.fbx")
    bpy.ops.export_scene.fbx(
        filepath=out_path,
        use_selection=True,
        object_types={"ARMATURE"},
        bake_anim=True,
        bake_anim_use_all_bones=True,
        bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=True,
        add_leaf_bones=False,
    )
    print(f"  exported: {out_path}")


def main():
    in_dir, out_dir = script_args()
    os.makedirs(out_dir, exist_ok=True)
    files = sorted(glob.glob(os.path.join(in_dir, "*.fbx")))
    if not files:
        raise SystemExit(f"no .fbx files in {in_dir}")
    for path in files:
        process(path, out_dir)


if __name__ == "__main__":
    main()
