"""Clover Bun v2: chunky chamfered-box style, sitting pose, two-tone, studs on top faces.

1 Blender unit = 1 Roblox stud. Front = -Y, up = +Z.
Body = one mesh (-> MeshPart). Face details = separate objects (-> Roblox parts).
"""
import math
import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

COLL = "CloverBun_v2"
STUD_SPACING = 0.33  # studs per tile edge in Blender units


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def stud_image(name, hexcol):
    """Tileable stud pattern baked onto the base color (one stud per tile)."""
    n = 64
    base = np.array(srgb(hexcol))
    yy, xx = np.mgrid[0:n, 0:n]
    u, v = (xx + 0.5) / n - 0.5, (yy + 0.5) / n - 0.5
    r = np.sqrt(u * u + v * v)
    shade = np.ones((n, n))
    ring = (r > 0.26) & (r < 0.32)
    top = r <= 0.26
    shade[ring] = np.where((u - v)[ring] > 0, 0.62, 1.25)  # rim: dark bottom-right, light top-left
    shade[top] = 1.14
    px = np.clip(base[None, None, :] * shade[..., None], 0, 1)
    rgba = np.concatenate([px, np.ones((n, n, 1))], axis=2).astype(np.float32)
    img = bpy.data.images.get(name) or bpy.data.images.new(name, n, n)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def mat(name, hexcol, studs=False):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = srgb(hexcol) + [1.0]
    if studs:
        m.use_nodes = True
        nt = m.node_tree
        tex = nt.nodes.get("Studs") or nt.nodes.new("ShaderNodeTexImage")
        tex.name = "Studs"
        tex.image = stud_image(name + "_img", hexcol)
        tex.interpolation = "Closest"
        bsdf = nt.nodes.get("Principled BSDF")
        if bsdf:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.nodes.active = tex
    return m


FUR = "#9BDB5A"
MATS = {
    "fur": mat("CB2_Fur", FUR),
    "fur_studs": mat("CB2_FurStuds", FUR, studs=True),
    "cream": mat("CB2_Cream", "#FFF3D6"),
    "pink": mat("CB2_Pink", "#FF8FB1"),
    "mark": mat("CB2_CloverMark", "#3E9E3A"),
    "sprout": mat("CB2_Sprout", "#58C23F"),
    "iris": mat("CB2_Iris", "#4A2E1C"),
    "black": mat("CB2_Black", "#151515"),
    "white": mat("CB2_White", "#FFFFFF"),
    "mouth": mat("CB2_Mouth", "#6B2430"),
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


def cbox(off=0.3, seg=2):
    """Unit cube (size 1) with chamfered edges -> chunky faceted block."""
    def f(bm):
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=off, offset_type="OFFSET",
                        segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    return f


def ico(sub):
    def f(bm):
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    return f


def cyl(seg):
    def f(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=1.0, radius2=1.0, depth=1.0)
    return f


def pyramid(seg=4):
    def f(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=1.0, radius2=0.0, depth=1.0)
    return f


class MeshBuilder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []
        self.ray_tris = []  # world-space triangles for ray casting face details

    def _mi(self, key):
        if key not in self.mats:
            self.mats.append(key)
        return self.mats.index(key)

    def add(self, shape, matrix, matkey, studs=False, raycast=False):
        tmp = bmesh.new()
        shape(tmp)
        bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        tmp.normal_update()
        if raycast:
            for f in tmp.faces:
                vs = [v.co.copy() for v in f.verts]
                for i in range(1, len(vs) - 1):
                    self.ray_tris.append((vs[0], vs[i], vs[i + 1]))
        vmap = {}
        for v in tmp.verts:
            vmap[v] = self.bm.verts.new(v.co)
        for f in tmp.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            stud_face = studs and f.normal.z > 0.6
            nf.material_index = self._mi(matkey + "_studs" if stud_face else matkey)
            for loop in nf.loops:
                c = loop.vert.co
                loop[self.uv].uv = (c.x / STUD_SPACING, c.y / STUD_SPACING)
        tmp.free()

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

    def bvh(self):
        verts, polys = [], []
        for tri in self.ray_tris:
            polys.append(tuple(range(len(verts), len(verts) + 3)))
            verts.extend(tri)
        return BVHTree.FromPolygons(verts, polys)


def part(name, shape, matrix, matkey, coll):
    mb = MeshBuilder()
    mb.add(shape, matrix, matkey)
    return mb.build(name, coll)


# ---------- reset only our own collection ----------
old = bpy.data.collections.get(COLL)
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o)
    bpy.data.collections.remove(old)
cb = bpy.data.collections.new(COLL)
bpy.context.scene.collection.children.link(cb)

mb = MeshBuilder()

# ---------- body: sitting bunny ----------
mb.add(cbox(0.32), T(0, 0.18, 0.52) @ S(0.98, 0.98, 0.86), "fur", studs=True)
mb.add(cbox(0.30), T(0, -0.20, 0.46) @ S(0.62, 0.30, 0.58), "cream")                 # belly
for side in (-1, 1):
    mb.add(cbox(0.30), T(side * 0.43, 0.22, 0.36) @ S(0.34, 0.66, 0.52), "fur", studs=True)  # haunch
    mb.add(cbox(0.25, 1), T(side * 0.40, -0.16, 0.10) @ RZ(side * -8) @ S(0.34, 0.72, 0.20), "cream")  # big hind foot
    mb.add(cbox(0.25, 1), T(side * 0.19, -0.42, 0.28) @ RX(10) @ S(0.19, 0.20, 0.30), "cream")  # front paw
mb.add(cbox(0.35), T(0, 0.74, 0.42) @ S(0.34, 0.30, 0.34), "cream")                  # puff tail

# clover mark on the back
hub = T(0, 0.685, 0.84)
for phi in (0, 120, -120):
    for lobe in (-1, 1):
        mb.add(ico(1), hub @ RY(phi) @ T(lobe * 0.05, 0, 0.11) @ RY(lobe * 20) @ S(0.075, 0.02, 0.11), "mark")

# ---------- head (tilted) ----------
H = T(0, -0.06, 1.22) @ RY(7) @ RX(-4)
mb.add(cbox(0.32), H @ S(1.32, 1.08, 1.04), "fur", studs=True, raycast=True)
mb.add(cbox(0.30), H @ T(0, -0.40, -0.18) @ S(1.04, 0.36, 0.62), "cream", raycast=True)  # face mask
# cheek fluff: small cream wedges at the lower corners of the face mask
for side in (-1, 1):
    for z, ang in ((-0.30, 35), (-0.42, 60)):
        mb.add(pyramid(4), H @ T(side * 0.50, -0.42, z) @ RY(side * (90 + ang)) @ T(0, 0, 0.06)
               @ S(0.08, 0.06, 0.16), "cream")
# ears: flat, widest in the middle, tapered tip; hexagonal cross-section (faceted).
# One continuous mesh per ear; the floppy one curves smoothly instead of kinking.
EAR_PROFILE = [(0.00, 0.11), (0.18, 0.18), (0.40, 0.21), (0.62, 0.20), (0.82, 0.15), (0.96, 0.08), (1.05, 0.0)]
EAR_Z = [i * 1.05 / 14 for i in range(15)]


def ear_width(z):
    for (z0, w0), (z1, w1) in zip(EAR_PROFILE, EAR_PROFILE[1:]):
        if z <= z1:
            return w0 + (w1 - w0) * (z - z0) / (z1 - z0)
    return 0.0


def ear(bend_axis=(1, 0, 0), bend_deg=0.0, hinge=0.35, wscale=1.0, thick=0.07, yoff=0.0, zmin=0.0, zmax=1.05):
    """Ear sampled on a fixed z grid so the fur shell and the pink inner bend identically."""
    axis = Vector(bend_axis).normalized()
    per_unit = math.radians(bend_deg) / (EAR_Z[-1] - hinge)

    def f(bm):
        R = Matrix.Identity(3)
        origin = Vector((0, 0, 0))
        rings = []
        for i, z in enumerate(EAR_Z):
            if i:
                dz = z - EAR_Z[i - 1]
                above = max(0.0, z - max(hinge, EAR_Z[i - 1]))
                R = Matrix.Rotation(per_unit * above, 3, axis) @ R  # bend first, then step along it
                origin = origin + R @ Vector((0, 0, dz))
            if z < zmin - 1e-6 or z > zmax + 1e-6:
                continue
            w = ear_width(z) * wscale
            if z >= zmax - 1e-6:
                w = 0.0
            if w <= 1e-4:
                rings.append([bm.verts.new(origin + R @ Vector((0, yoff, 0)))])
                break
            t = thick
            prof = [(-w, 0), (-w * 0.55, -t), (w * 0.55, -t), (w, 0), (w * 0.55, t), (-w * 0.55, t)]
            rings.append([bm.verts.new(origin + R @ Vector((x, y + yoff, 0))) for x, y in prof])
        bm.faces.new(list(reversed(rings[0])))
        for r0, r1 in zip(rings, rings[1:]):
            n = len(r0)
            for i in range(n):
                j = (i + 1) % n
                if len(r1) == 1:
                    bm.faces.new([r0[i], r0[j], r1[0]])
                else:
                    bm.faces.new([r0[i], r0[j], r1[j], r1[i]])
    return f


for side in (-1, 1):
    E = H @ T(side * 0.32, 0.06, 0.42) @ RY(side * 10) @ RX(-6)
    if side > 0:   # upright ear with a slight backward curve
        bend = dict(bend_axis=(1, 0, 0), bend_deg=-14, hinge=0.3)
    else:          # floppy ear: curves outward and a bit forward, tip hangs down
        bend = dict(bend_axis=(0.35, -1, 0), bend_deg=115, hinge=0.42)
    mb.add(ear(**bend), E, "fur")
    mb.add(ear(**bend, wscale=0.6, thick=0.02, yoff=-0.06, zmin=0.075, zmax=0.975), E, "pink")
# clover sprout between the ears
sp = H @ T(0.02, -0.12, 0.50) @ RX(12)
mb.add(cyl(6), sp @ T(0, 0, 0.10) @ S(0.035, 0.035, 0.22), "sprout")
for phi in (0, 120, -120):
    for lobe in (-1, 1):
        mb.add(ico(1), sp @ T(0, 0, 0.22) @ RY(phi) @ T(lobe * 0.05, 0, 0.11) @ RY(lobe * 20)
               @ S(0.075, 0.025, 0.11), "sprout")

bvh = mb.bvh()
body = mb.build("CloverBun_Body", cb)


# ---------- face parts, placed by ray casting onto the head ----------
def on_face(name, lx, lz, out, shape, scale, matkey, local=(0, 0), extra=Matrix()):
    origin = H @ Vector((lx, -3.0, lz))
    direction = (H.to_3x3() @ Vector((0, 1, 0))).normalized()
    hit, normal, _, _ = bvh.ray_cast(origin, direction)
    rot = normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
    m = T(*(hit + normal * out)) @ rot @ T(local[0], local[1], 0) @ extra @ S(*scale)
    return part(name, shape, m, matkey, cb)


for side, tag in ((-1, "L"), (1, "R")):
    x = side * 0.29
    on_face(f"Eye{tag}", x, 0.10, 0.0, cyl(12), (0.22, 0.24, 0.08), "iris")
    on_face(f"Pupil{tag}", x, 0.10, 0.035, cyl(12), (0.14, 0.16, 0.04), "black", (side * 0.015, -0.01))
    on_face(f"Shine{tag}_Big", x, 0.10, 0.055, cyl(10), (0.06, 0.06, 0.02), "white", (-0.06, 0.08))
    on_face(f"Shine{tag}_Small", x, 0.10, 0.055, cyl(8), (0.03, 0.03, 0.02), "white", (0.07, -0.07))
    on_face(f"Blush{tag}", side * 0.47, -0.15, 0.0, cyl(10), (0.10, 0.06, 0.03), "pink")
on_face("Nose", 0, -0.12, 0.02, pyramid(3), (0.07, 0.05, 0.04), "pink", extra=RX(180) @ RZ(180))
on_face("Mouth", 0, -0.29, 0.0, cyl(12), (0.15, 0.06, 0.03), "mouth")
on_face("Tooth", 0, -0.255, 0.02, cbox(0.2, 1), (0.08, 0.05, 0.03), "white")

# ---------- stats ----------
bm = bmesh.new()
bm.from_mesh(body.data)
tris = sum(len(f.verts) - 2 for f in bm.faces)
bm.free()
result = {"body_tris": tris, "parts": len(cb.objects) - 1,
          "height": round(max((body.matrix_world @ v.co).z for v in body.data.vertices), 2)}
