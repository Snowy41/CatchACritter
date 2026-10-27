import bpy
result = {
    "version": bpy.app.version_string,
    "file": bpy.data.filepath,
    "objects": [o.name for o in bpy.data.objects],
}
