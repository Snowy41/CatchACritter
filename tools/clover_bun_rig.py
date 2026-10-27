"""Rig Clover Bun v2 for Roblox: palette texture, armature, rigid skinning, idle animation, FBX export.

Run after clover_bun_v2.py. Works on a copy, so the CloverBun_v2 collection stays untouched.
Result: collection "CloverBun_Rig" (armature "CloverBun" + mesh "CloverBun_Mesh") and
models/export/CloverBun.fbx (+ CloverBun_palette.png).
"""
import math
import os
import bmesh
import bpy
import numpy as np
from mathutils import Vector

SRC = "CloverBun_v2"
DST = "CloverBun_Rig"
EXPORT_DIR = r"C:\Users\tobia\Downloads\CatchACritter\models\export"
FPS, LOOP = 30, 90  # 3 second idle loop

os.makedirs(EXPORT_DIR, exist_ok=True)
scene = bpy.context.scene
if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")

# ---------- fresh target collection ----------
old = bpy.data.collections.get(DST)
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(old)
dst = bpy.data.collections.new(DST)
scene.collection.children.link(dst)
for c in scene.collection.children:
    c.hide_viewport = c.name not in (DST, "ScaleAvatar")

# ---------- join copies of all source meshes into one ----------
src = bpy.data.collections[SRC]
copies = []
for o in src.objects:
    if o.type != "MESH":
        continue
    c = o.copy()
    c.data = o.data.copy()
    dst.objects.link(c)
    c.matrix_world = o.matrix_world
    copies.append(c)
body = next(c for c in copies if c.name.startswith("CloverBun_Body"))
bpy.ops.object.select_all(action="DESELECT")
for c in copies:
    c.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
mesh_ob = bpy.context.view_layer.objects.active
mesh_ob.name = "CloverBun_Mesh"
mesh_ob.data.name = "CloverBun_Mesh"

# ---------- palette texture: one swatch per material colour ----------
mats = [m for m in mesh_ob.data.materials]
key_of = {}
swatches = []
for i, m in enumerate(mats):
    k = m.name.replace("Studs", "").replace("_img", "")
    col = tuple(round(x, 4) for x in m.diffuse_color[:3])
    if col not in swatches:
        swatches.append(col)
    key_of[i] = swatches.index(col)
GRID = 4  # 4x4 swatches
N = 64
cell = N // GRID
px = np.ones((N, N, 4), dtype=np.float32)
for idx, col in enumerate(swatches):
    gx, gy = idx % GRID, idx // GRID
    # image pixels are linear in Blender's buffer; diffuse_color is linear too
    px[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell, :3] = col
img = bpy.data.images.get("CloverBun_palette") or bpy.data.images.new("CloverBun_palette", N, N)
img.scale(N, N)
img.colorspace_settings.name = "sRGB"
# convert linear -> sRGB for storage
lin = px[..., :3]
srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
px[..., :3] = srgb
img.pixels.foreach_set(px.ravel())
img.filepath_raw = os.path.join(EXPORT_DIR, "CloverBun_palette.png")
img.file_format = "PNG"
img.save()

bm = bmesh.new()
bm.from_mesh(mesh_ob.data)
uv = bm.loops.layers.uv.verify()
for f in bm.faces:
    idx = key_of.get(f.material_index, 0)
    gx, gy = idx % GRID, idx // GRID
    u = (gx + 0.5) / GRID
    v = (gy + 0.5) / GRID
    for loop in f.loops:
        loop[uv].uv = (u, v)
    f.material_index = 0
bm.to_mesh(mesh_ob.data)
bm.free()

pal = bpy.data.materials.get("CloverBun_Palette") or bpy.data.materials.new("CloverBun_Palette")
pal.use_nodes = True
nt = pal.node_tree
tex = nt.nodes.get("Palette") or nt.nodes.new("ShaderNodeTexImage")
tex.name = "Palette"
tex.image = img
tex.interpolation = "Closest"
bsdf = nt.nodes.get("Principled BSDF")
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
nt.nodes.active = tex
mesh_ob.data.materials.clear()
mesh_ob.data.materials.append(pal)

# ---------- classify mesh islands -> bone groups ----------
GROUPS = ["Body", "Head", "EarL", "EarR", "Tail", "Sprout"]
vg = {g: mesh_ob.vertex_groups.new(name=g) for g in GROUPS}
bm = bmesh.new()
bm.from_mesh(mesh_ob.data)
bm.verts.ensure_lookup_table()
seen = set()
assign = {g: [] for g in GROUPS}
for v in bm.verts:
    if v.index in seen:
        continue
    stack, island = [v], []
    seen.add(v.index)
    while stack:
        cur = stack.pop()
        island.append(cur.index)
        for e in cur.link_edges:
            o = e.other_vert(cur)
            if o.index not in seen:
                seen.add(o.index)
                stack.append(o)
    cen = sum((bm.verts[i].co for i in island), Vector()) / len(island)
    zmin = min(bm.verts[i].co.z for i in island)
    if zmin > 1.55 and abs(cen.x) > 0.18:
        g = "EarL" if cen.x < 0 else "EarR"
    elif zmin > 1.6 and abs(cen.x) <= 0.18:
        g = "Sprout"
    elif cen.y > 0.6 and cen.z < 0.7:
        g = "Tail"
    elif cen.z > 0.72 and cen.y < 0.6:
        g = "Head"
    else:
        g = "Body"
    assign[g].extend(island)
bm.free()
for g, idxs in assign.items():
    if idxs:
        vg[g].add(idxs, 1.0, "REPLACE")
counts = {g: len(v) for g, v in assign.items()}

# ---------- armature ----------
arm_data = bpy.data.armatures.new("CloverBun")
arm = bpy.data.objects.new("CloverBun", arm_data)
dst.objects.link(arm)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones


def bone(name, head, tail, parent=None):
    b = eb.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    if parent:
        b.parent = eb[parent]
    return b


bone("Root", (0, 0.1, 0), (0, 0.1, 0.25))
bone("Body", (0, 0.12, 0.25), (0, 0.06, 0.80), "Root")
bone("Head", (0, -0.04, 0.80), (0, -0.08, 1.55), "Body")
bone("EarL", (-0.27, 0.0, 1.67), (-0.33, 0.06, 2.10), "Head")
bone("EarR", (0.37, 0.0, 1.60), (0.45, 0.06, 2.12), "Head")
bone("Sprout", (0.0, -0.13, 1.70), (0.0, -0.16, 1.98), "Head")
bone("Tail", (0, 0.66, 0.44), (0, 0.92, 0.46), "Body")
bpy.ops.object.mode_set(mode="OBJECT")

mesh_ob.parent = arm
mod = mesh_ob.modifiers.new("Armature", "ARMATURE")
mod.object = arm

# ---------- idle animation ----------
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 0, LOOP - 1
arm.animation_data_create()
act = bpy.data.actions.get("Idle")
if act:
    bpy.data.actions.remove(act)
act = bpy.data.actions.new("Idle")
arm.animation_data.action = act
pb = arm.pose.bones
for p in pb:
    p.rotation_mode = "XYZ"


def wave(f, period, amp, phase=0.0):
    return amp * math.sin(2 * math.pi * (f / period + phase))


for f in range(0, LOOP + 1, 3):
    scene.frame_set(f)
    t = f
    # breathing: body rises/sinks a little, slight forward lean
    pb["Body"].location = (0, wave(t, 45, 0.018), 0)
    pb["Body"].rotation_euler = (math.radians(wave(t, 90, 1.5)), 0, 0)
    # head: slow sway + gentle nod (counter to the body)
    pb["Head"].rotation_euler = (math.radians(wave(t, 90, 3.0, 0.25)), 0, math.radians(wave(t, 90, 4.5)))
    # floppy ear sways, upright ear twitches once per loop
    pb["EarL"].rotation_euler = (0, 0, math.radians(wave(t, 45, 7.0)))
    twitch = 0.0
    if 54 <= t <= 66:
        twitch = math.sin((t - 54) / 12 * math.pi) * -18
    pb["EarR"].rotation_euler = (math.radians(twitch), 0, math.radians(wave(t, 90, 3.0, 0.5)))
    # tail wiggle, sprout bob
    pb["Tail"].rotation_euler = (0, 0, math.radians(wave(t, 30, 14.0)))
    pb["Sprout"].rotation_euler = (math.radians(wave(t, 45, 8.0, 0.1)), 0, math.radians(wave(t, 90, 6.0)))
    for name in ("Body", "Head", "EarL", "EarR", "Tail", "Sprout"):
        pb[name].keyframe_insert("rotation_euler", frame=f)
    pb["Body"].keyframe_insert("location", frame=f)
scene.frame_set(0)

# ---------- export FBX ----------
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
mesh_ob.select_set(True)
bpy.context.view_layer.objects.active = arm
fbx_path = os.path.join(EXPORT_DIR, "CloverBun.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx_path, use_selection=True, object_types={"ARMATURE", "MESH"},
    apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", global_scale=1.0,
    axis_forward="-Z", axis_up="Y", add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X",
    mesh_smooth_type="FACE", use_armature_deform_only=True,
    bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
    bake_anim_force_startend_keying=True, bake_anim_step=1.0, bake_anim_simplify_factor=0.0,
    path_mode="COPY", embed_textures=True,
)
tris = sum(len(p.vertices) - 2 for p in mesh_ob.data.polygons)
result = {"fbx": fbx_path, "tris": tris, "swatches": len(swatches), "groups": counts, "bones": [b.name for b in arm_data.bones]}
