import bpy
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\elles\Desktop\Builts\Medieval-Town\source-assets\all-together\All together\Blends\All together.blend')
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
print('TARGET_BONES',[b.name for b in rig.data.bones],flush=True)
bpy.ops.import_scene.fbx(filepath=r'C:\Users\elles\Downloads\runner\Running.fbx')
for o in bpy.data.objects:
 if o.type=='ARMATURE' and o!=rig:
  print('RUNNER_RIG',o.name,list(o.scale),list(o.rotation_euler),flush=True)
  print('SOURCE_BONES',[b.name for b in o.data.bones],flush=True)
  print('ACTION',o.animation_data.action.name,list(o.animation_data.action.frame_range),flush=True)
