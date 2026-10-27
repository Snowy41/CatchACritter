"""Export the rigged Clover Bun (CloverBun_Rig) as a compact Luau data module for Roblox Studio.

Coordinates are converted Blender (Z up, front -Y) -> Roblox (Y up, front -Z):  p_r = (-x, z, y).
Writes tools/cloverbun_data.lua containing:
  V   flat vertex positions (mesh-local, centred on the bounding box)
  F   flat triangles: a, b, c, colourIndex (1-based)
  C   palette colours as {r, g, b} 0-255
  VB  bone index per vertex (1-based, rigid skinning)
  B   bones: {name, parentIndex, px, py, pz, r00..r22} bind pose in mesh-local space
  K   idle keyframes: {time, {boneIndex -> {px,py,pz, qx,qy,qz,qw}}} in bone-local space
"""
import math
import bpy
from mathutils import Matrix, Vector

OUT = r"C:\Users\tobia\Downloads\CatchACritter\tools\cloverbun_data.lua"
R = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))  # Blender -> Roblox (proper rotation, det = +1)

arm = bpy.data.objects["CloverBun"]
mesh_ob = bpy.data.objects["CloverBun_Mesh"]
scene = bpy.context.scene
scene.frame_set(0)
# rest pose for geometry/bones
arm.data.pose_position = "REST"
bpy.context.view_layer.update()

me = mesh_ob.data
mw = mesh_ob.matrix_world
verts_r = [R @ (mw @ v.co) for v in me.vertices]
lo = Vector((min(v.x for v in verts_r), min(v.y for v in verts_r), min(v.z for v in verts_r)))
hi = Vector((max(v.x for v in verts_r), max(v.y for v in verts_r), max(v.z for v in verts_r)))
center = (lo + hi) / 2
verts_l = [v - center for v in verts_r]

# palette colours from the palette image via each face's UV
img = bpy.data.images["CloverBun_palette"]
W, H = img.size
pix = list(img.pixels)
uv_layer = me.uv_layers.active.data


def color_at(u, v):
    x = min(W - 1, max(0, int(u * W)))
    y = min(H - 1, max(0, int(v * H)))
    i = (y * W + x) * 4
    return tuple(int(round(min(1.0, max(0.0, pix[i + k])) * 255)) for k in range(3))


palette, tris = [], []
for poly in me.polygons:
    loop0 = poly.loop_indices[0]
    col = color_at(*uv_layer[loop0].uv)
    if col not in palette:
        palette.append(col)
    ci = palette.index(col) + 1
    vs = list(poly.vertices)
    for k in range(1, len(vs) - 1):
        # Roblox uses counter-clockwise front faces; the coordinate change keeps handedness, so keep order
        tris.append((vs[0] + 1, vs[k] + 1, vs[k + 1] + 1, ci))

bone_names = [b.name for b in arm.data.bones]
bidx = {n: i + 1 for i, n in enumerate(bone_names)}
vb = []
for v in me.vertices:
    best, bw = "Body", -1
    for g in v.groups:
        name = mesh_ob.vertex_groups[g.group].name
        if name in bidx and g.weight > bw:
            best, bw = name, g.weight
    vb.append(bidx[best])

bones = []
for b in arm.data.bones:
    m = arm.matrix_world @ b.matrix_local          # rest matrix in Blender world
    rot = R @ m.to_3x3()                           # bone axes expressed in Roblox world
    pos = R @ m.to_translation() - center
    bones.append((b.name, bidx[b.parent.name] if b.parent else 0, pos, rot))

# idle animation: sample pose bones (matrix_basis = bone-local, same convention as Roblox Bone.Transform)
arm.data.pose_position = "POSE"
keys = []
for f in range(scene.frame_start, scene.frame_end + 2, 3):
    scene.frame_set(f)
    frame = []
    for pb in arm.pose.bones:
        mb = pb.matrix_basis
        q = mb.to_quaternion()
        t = mb.to_translation()
        frame.append((bidx[pb.name], t, q))
    keys.append(((f - scene.frame_start) / scene.render.fps, frame))
scene.frame_set(0)


def n(x):
    s = f"{x:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


lines = ["return {"]
lines.append("V={" + ",".join(f"{n(v.x)},{n(v.y)},{n(v.z)}" for v in verts_l) + "},")
lines.append("F={" + ",".join(f"{a},{b},{c},{ci}" for a, b, c, ci in tris) + "},")
lines.append("C={" + ",".join(f"{{{r},{g},{bb}}}" for r, g, bb in palette) + "},")
lines.append("VB={" + ",".join(str(i) for i in vb) + "},")
bl = []
for name, parent, pos, rot in bones:
    rv = ",".join(n(rot[i][j]) for i in range(3) for j in range(3))
    bl.append(f'{{"{name}",{parent},{n(pos.x)},{n(pos.y)},{n(pos.z)},{rv}}}')
lines.append("B={" + ",".join(bl) + "},")
kl = []
for t, frame in keys:
    parts = ",".join(f"[{i}]={{{n(tr.x)},{n(tr.y)},{n(tr.z)},{n(q.x)},{n(q.y)},{n(q.z)},{n(q.w)}}}" for i, tr, q in frame)
    kl.append(f"{{{n(t)},{{{parts}}}}}")
lines.append("K={" + ",".join(kl) + "},")
lines.append(f"Size={{{n(hi.x - lo.x)},{n(hi.y - lo.y)},{n(hi.z - lo.z)}}},")
lines.append("}")
src = "\n".join(lines)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write(src)
result = {"verts": len(verts_l), "tris": len(tris), "colors": len(palette), "bones": bone_names,
          "keys": len(keys), "bytes": len(src), "size": [round(hi.x - lo.x, 2), round(hi.y - lo.y, 2), round(hi.z - lo.z, 2)]}
