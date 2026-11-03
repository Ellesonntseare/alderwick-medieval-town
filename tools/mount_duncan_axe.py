import bpy,pathlib
from mathutils import Vector,Matrix
root=pathlib.Path(__file__).resolve().parents[1]
path=root/'source-assets/rigged-characters/bruce.blend'
bpy.ops.wm.open_mainfile(filepath=str(path))
axe=bpy.data.objects.get('Object_35')
if axe:
    points=[v.co.copy() for v in axe.data.vertices]
    low=Vector(tuple(min(p[k] for p in points) for k in range(3)))
    high=Vector(tuple(max(p[k] for p in points) for k in range(3)))
    centre=(low+high)/2
    turn=Matrix.Rotation(1.5707963267948966,3,'X')
    for vertex in axe.data.vertices:vertex.co=turn@(vertex.co-centre)+Vector((-.25,.17,.86))
    axe.vertex_groups.clear()
    axe.vertex_groups.new(name='Hips').add(list(range(len(axe.data.vertices))),1,'REPLACE')
    axe.name='Equipment_Axe'
bpy.context.scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(path))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(root/'game/characters/bruce.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True)
print('DUNCAN_AXE_MOUNTED hip_rigid=true')
