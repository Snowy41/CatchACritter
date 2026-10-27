"""Build Clover Bun (Common Meadow critter) in Blender. 1 Blender unit = 1 Roblox stud.

Body = one low-poly mesh (becomes a MeshPart). Eyes, pupils, highlights, nose, blush =
separate simple objects (become Roblox parts: cylinders / balls).
"""
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = r"C:\Users\tobia\Downloads\CatchACritter\models"


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


def mat(name, hexcol):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = srgb(hexcol)
    return m


MATS = {
    "cream": mat("CB_Cream", "#FFF4DC"),
    "white": mat("CB_White", "#FFFFFF"),
    "brown": mat("CB_Brown", "#B07A4A"),
    "green": mat("CB_Green", "#8BE35F"),
    "dgreen": mat("CB_DarkGreen", "#4FAE3A"),
    "pink": mat("CB_Pink", "#FF8FB1"),
    "iris": mat("CB_Iris", "#5A3A22"),
    "black": mat("CB_Black", "#1A1A1A"),
    "yellow": mat("AV_Yellow", "#F5CD30"),
    "blue": mat("AV_Blue", "#0D69AC"),
    "agreen": mat("AV_Green", "#4B974B"),
}


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def S(x, y, z):
    return Matrix.Diagonal((x, y, z, 1.0))


def RX(d):
    return Matrix.Rotation(math.radians(d), 4, "X")


def RY(d):
    return Matrix.Rotation(math.radians(d), 4, "Y")


def RZ(d):
    return Matrix.Rotation(math.radians(d), 4, "Z")


def ico(sub):
    def f(bm):
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    return f


def cyl(seg):
    def f(bm):  # unit cylinder: radius 1, height 1, axis Z, centered
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=1.0, radius2=1.0, depth=1.0)
    return f


def box(bm):
    bmesh.ops.create_cube(bm, size=1.0)


class MeshBuilder:
    """Collects pieces into one mesh, each piece with its own material."""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def add(self, shape, matrix, matkey):
        tmp = bmesh.new()
        shape(tmp)
        bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        if matkey not in self.mats:
            self.mats.append(matkey)
        idx = self.mats.index(matkey)
        for f in tmp.faces:
            f.material_index = idx
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def build(self, name, coll):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = False
        for k in self.mats:
            me.materials.append(MATS[k])
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        return ob


def part(name, shape, matrix, matkey, coll):
    mb = MeshBuilder()
    mb.add(shape, matrix, matkey)
    return mb.build(name, coll)


# ---------- scene reset (only our own stuff + the default cube) ----------
for n in ("Cube",):
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n])
for cname in ("CloverBun", "ScaleAvatar"):
    c = bpy.data.collections.get(cname)
    if c:
        for o in list(c.objects):
            bpy.data.objects.remove(o)
        bpy.data.collections.remove(c)

root = bpy.context.scene.collection
cb = bpy.data.collections.new("CloverBun")
root.children.link(cb)

# ---------- proportions ----------
HEAD_C = Vector((0.0, -0.10, 1.08))
HEAD_R = Vector((0.68, 0.60, 0.58))


def head_surface(x, z):
    """Point + normal on the head ellipsoid front at (x, z)."""
    dx, dz = x - HEAD_C.x, z - HEAD_C.z
    t = 1 - (dx / HEAD_R.x) ** 2 - (dz / HEAD_R.z) ** 2
    dy = -HEAD_R.y * math.sqrt(max(t, 0.0))
    p = Vector((x, HEAD_C.y + dy, z))
    n = Vector((dx / HEAD_R.x ** 2, dy / HEAD_R.y ** 2, dz / HEAD_R.z ** 2)).normalized()
    return p, n


# ---------- body mesh ----------
mb = MeshBuilder()
# big head overlapping a small round body (no neck)
mb.add(ico(3), T(*HEAD_C) @ S(*HEAD_R), "cream")
mb.add(ico(3), T(0, 0.16, 0.46) @ S(0.48, 0.58, 0.40), "cream")
# chest patch
mb.add(ico(2), T(0, -0.22, 0.42) @ RX(-20) @ S(0.28, 0.12, 0.22), "white")
# muzzle puffs (two small lobes under the nose)
for side in (-1, 1):
    p, n = head_surface(side * 0.075, 0.90)
    mb.add(ico(2), T(*(p - n * 0.02)) @ S(0.11, 0.07, 0.085), "white")
# stubby legs
for x in (-0.25, 0.25):
    for y in (-0.16, 0.40):
        mb.add(cyl(6), T(x, y, 0.12) @ S(0.14, 0.14, 0.24), "cream")
        mb.add(cyl(6), T(x, y - 0.03, 0.035) @ S(0.155, 0.17, 0.07), "brown")
# puff tail
mb.add(ico(2), T(0, 0.74, 0.55) @ S(0.17, 0.15, 0.17), "white")
# long bunny ears with a clover-leaf inside
for side in (-1, 1):
    base = T(side * 0.26, -0.02, 1.50) @ RY(side * 14) @ RX(-10)
    mb.add(ico(2), base @ T(0, 0, 0.40) @ S(0.16, 0.075, 0.42), "cream")
    mb.add(ico(2), base @ T(0, -0.05, 0.42) @ S(0.11, 0.035, 0.32), "green")
    mb.add(box, base @ T(0, -0.075, 0.42) @ S(0.025, 0.02, 0.50), "dgreen")
# little three-leaf clover sprout on top of the head
sprout = T(0, -0.10, 1.62) @ RX(8)
mb.add(cyl(6), sprout @ T(0, 0, 0.09) @ S(0.03, 0.03, 0.18), "dgreen")
hub = sprout @ T(0, 0, 0.19)
for phi in (0, 120, -120):
    for lobe in (-1, 1):
        mb.add(ico(1), hub @ RY(phi) @ T(lobe * 0.04, 0, 0.10) @ RY(lobe * 18) @ S(0.06, 0.022, 0.09), "green")
body = mb.build("CloverBun_Body", cb)

# ---------- parts (become Roblox parts) ----------
def on_head(name, x, z, out, shape, scale, matkey, local=(0, 0)):
    p, n = head_surface(x, z)
    rot = n.to_track_quat("Z", "Y").to_matrix().to_4x4()
    m = T(*(p + n * out)) @ rot @ T(local[0], local[1], 0) @ S(*scale)
    return part(name, shape, m, matkey, cb)


for side, tag in ((-1, "L"), (1, "R")):
    x, z = side * 0.27, 1.16
    on_head(f"Eye{tag}", x, z, 0.0, cyl(12), (0.18, 0.19, 0.07), "iris")
    on_head(f"Pupil{tag}", x, z, 0.03, cyl(12), (0.115, 0.125, 0.04), "black")
    on_head(f"Shine{tag}_Big", x, z, 0.05, cyl(10), (0.05, 0.05, 0.02), "white", (-0.05, 0.06))
    on_head(f"Shine{tag}_Small", x, z, 0.05, cyl(8), (0.025, 0.025, 0.02), "white", (0.06, -0.06))
    on_head(f"Blush{tag}", side * 0.47, 0.96, 0.0, cyl(10), (0.09, 0.055, 0.03), "pink")
np_, nn_ = head_surface(0, 0.99)
part("Nose", ico(1), T(*(np_ + nn_ * 0.03)) @ S(0.07, 0.05, 0.05), "pink", cb)

# ---------- scale avatar: classic 5-stud R6 blocky character ----------
av = bpy.data.collections.new("ScaleAvatar")
root.children.link(av)
AX = 2.4
avmb = MeshBuilder()
avmb.add(box, T(AX - 0.5, 0, 1.0) @ S(1, 1, 2), "agreen")
avmb.add(box, T(AX + 0.5, 0, 1.0) @ S(1, 1, 2), "agreen")
avmb.add(box, T(AX, 0, 3.0) @ S(2, 1, 2), "blue")
avmb.add(box, T(AX - 1.5, 0, 3.0) @ S(1, 1, 2), "yellow")
avmb.add(box, T(AX + 1.5, 0, 3.0) @ S(1, 1, 2), "yellow")
avmb.add(cyl(16), T(AX, 0, 4.6) @ S(0.6, 0.6, 1.2), "yellow")
avmb.build("Avatar_5studs", av)

# ---------- stats ----------
bm = bmesh.new()
bm.from_mesh(body.data)
tris = sum(len(f.verts) - 2 for f in bm.faces)
bm.free()
parts = [o.name for o in cb.objects if o is not body]
result = {"body_tris": tris, "parts": len(parts), "part_names": parts}
