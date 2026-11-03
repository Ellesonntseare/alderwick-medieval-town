import bpy,pathlib
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town')
bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/all-together/All together/Blends/All together.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for a in list(bpy.data.actions):
 if a.name!='Idle_Neutral':bpy.data.actions.remove(a)
rig.animation_data_create();rig.animation_data.action=bpy.data.actions['Idle_Neutral'];bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.hide_viewport=False;rig.hide_select=False;rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(R/'game/characters/neutral_motion.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS')
print('NEUTRAL_STANCE_EXPORTED',flush=True)
