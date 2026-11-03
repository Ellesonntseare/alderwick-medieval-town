import bpy,pathlib
from mathutils import Matrix,Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source-assets'/'all-together'/'All together'/'Blends'/'All together.blend'))
target=next(o for o in bpy.data.objects if o.type=='ARMATURE')
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for bone in target.pose.bones:
 for c in list(bone.constraints):bone.constraints.remove(c)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
mapping={'Hips':'pelvis','Abdomen':'spine_01','Torso':'spine_02','Chest':'spine_03','Neck':'neck_01','Head':'Head'}
for side,suffix in [('L','l'),('R','r')]:
 for t,s in [('Shoulder','clavicle'),('UpperArm','upperarm'),('LowerArm','lowerarm'),('Wrist','hand'),('UpperLeg','thigh'),('LowerLeg','calf'),('Foot','foot'),('PT','ball')]:mapping[t+'.'+side]=s+'_'+suffix
generated_names=[]
packs=[(ROOT/'source-assets'/'universal-animations'/'Universal Animation Library[Standard]'/'Unreal-Godot'/'UAL1_Standard.glb',{'Sitting_Enter':'SitEnter','Sitting_Idle_Loop':'SitIdle','Sitting_Exit':'SitExit','PickUp_Table':'WorkTable'}),
 (ROOT/'source-assets'/'universal-animation-library-2'/'Universal Animation Library 2[Standard]'/'Unreal-Godot'/'UAL2_Standard.glb',{'LayToIdle':'SleepExit','Farm_Harvest':'WorkHarvest'})]
for file,clips in packs:
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(file))
 imported=[o for o in bpy.data.objects if o not in before]
 source=next(o for o in imported if o.type=='ARMATURE')
 actions={a.name:a for a in bpy.data.actions}
 print('SOURCE_BONES',[b.name for b in source.data.bones],flush=True)
 for source_name,name in clips.items():
  action=next((a for a in actions.values() if a.name==source_name or a.name.endswith('|'+source_name)),None)
  assert action,source_name
  source.animation_data_create();source.animation_data.action=action
  start,end=map(int,action.frame_range)
  target.animation_data_create();target.animation_data.action=None
  for bone in target.pose.bones:bone.matrix_basis=Matrix.Identity(4)
  generated=bpy.data.actions.new(name);generated_names.append(name)
  target.animation_data.action=generated
  for frame in range(start,end+1):
   bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
   for bone in target.pose.bones:
    source_bone=mapping.get(bone.name)
    src=source.pose.bones.get(source_bone) if source_bone else None
    if not src:continue
    rest=(source.matrix_world@src.bone.matrix_local).to_quaternion()
    pose=(source.matrix_world@src.matrix).to_quaternion()
    target_rest=(target.matrix_world@bone.bone.matrix_local).to_quaternion()
    desired=target.matrix_world.to_quaternion().inverted()@(pose@rest.inverted()@target_rest)
    relative=bone.parent.bone.matrix_local.inverted()@bone.bone.matrix_local if bone.parent else bone.bone.matrix_local
    location=bone.parent.matrix@relative.translation if bone.parent else relative.translation
    bone.matrix=Matrix.LocRotScale(location,desired,Vector((1,1,1)))
    bone.rotation_mode='QUATERNION';bone.keyframe_insert(data_path='rotation_quaternion',frame=frame-start,group=bone.name)
    bpy.context.view_layer.update()
  print('DAILY_RETARGET',source_name,'->',name,'frames',end-start+1,flush=True)
 for o in imported:bpy.data.objects.remove(o,do_unlink=True)
 for a in list(bpy.data.actions):
  if a.name not in generated_names:bpy.data.actions.remove(a)
bpy.ops.object.select_all(action='DESELECT')
target.hide_set(False);target.hide_viewport=False;target.hide_render=False;target.hide_select=False;target.select_set(True)
bpy.context.view_layer.objects.active=target
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game'/'characters'/'daily_motion.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS')
print('DAILY_MOTION_READY',generated_names,flush=True)
