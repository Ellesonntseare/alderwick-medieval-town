"""Remove the source's scattered spare arrows from the walking copy."""
import bpy, pathlib, json
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1]
path=root/'source-assets/rigged-characters/cult_archer.blend'
bpy.ops.wm.open_mainfile(filepath=str(path))
bpy.context.scene.frame_set(0)
removed=[]
for obj in list(bpy.data.objects):
    if obj.type!='MESH' or 'arrow' not in obj.name.lower():
        continue
    points=[obj.matrix_world @ Vector(p) for p in obj.bound_box]
    low=min(p.z for p in points)
    high=max(p.z for p in points)
    # Keep arrows in the back quiver and the arrow held at chest height.
    # The supplied display also includes loose arrows scattered at floor level.
    if high < .65:
        removed.append(dict(name=obj.name,low=low,high=high))
        bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(path))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(root/'game/characters/cult_archer.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True)
(root/'review/characters/archer-equipment-cleanup.json').write_text(json.dumps(removed,indent=2))
print('ARCHER_SCATTERED_ARROWS_REMOVED',len(removed))
