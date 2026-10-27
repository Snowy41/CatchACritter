"""Render front / side / back / 3-4 views (+ one with the scale avatar) with Workbench."""
import math
import os
import bpy
from mathutils import Vector

OUT = r"C:\Users\tobia\Downloads\CatchACritter\models\renders"
PREFIX = globals().get("PREFIX", "cloverbun")
SHOW = globals().get("SHOW", None)  # collection names to render; others hidden
os.makedirs(OUT, exist_ok=True)

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = sc.render.resolution_y = 900
sc.render.film_transparent = False
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_object_outline = True
sc.display.shading.object_outline_color = (0.1, 0.1, 0.1)
sc.display.shading.show_cavity = False
sc.display.shading.show_shadows = False
sc.display.shading.show_specular_highlight = False
sc.view_settings.view_transform = "Standard"
if sc.world is None:
    sc.world = bpy.data.worlds.new("World")
sc.world.color = (0.62, 0.62, 0.64)

cam = bpy.data.objects.get("RenderCam")
if cam is None:
    cam = bpy.data.objects.new("RenderCam", bpy.data.cameras.new("RenderCam"))
    sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"

av = bpy.data.collections["ScaleAvatar"]
if SHOW:
    for c in bpy.data.collections:
        if c is not av:
            c.hide_render = c.name not in SHOW


def shot(name, eye, target, ortho, avatar=False):
    av.hide_render = not avatar
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = ortho
    sc.render.filepath = os.path.join(OUT, f"{PREFIX}_{name}.png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


C = (0, 0, 1.3)
files = [
    shot("front", (0, -10, 1.3), C, 3.2),
    shot("side", (-10, 0, 1.3), C, 3.2),
    shot("back", (0, 10, 1.3), C, 3.2),
    shot("34", (-7, -7, 4.8), C, 3.2),
    shot("scale", (-3, -10, 4.0), (1.2, 0, 2.5), 7.0, avatar=True),
]
av.hide_render = False
result = {"files": files}
