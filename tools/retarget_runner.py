import bpy,pathlib,json,math
from mathutils import Matrix,Vector,Euler
R=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/all-together/All together/Blends/All together.blend'))
target=next(o for o in bpy.data.objects if o.type=='ARMATURE')
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for bone in target.pose.bones:
 for c in list(bone.constraints):bone.constraints.remove(c)
target.animation_data_create();target.animation_data.action=bpy.data.actions['Idle_Neutral'];bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
finger_pose={b.name:b.matrix_basis.copy() for b in target.pose.bones if b.name.startswith(('Index','Middle','Ring','Pinky','Thumb'))}
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
mapping={'Hips':'Hips','Abdomen':'Spine','Torso':'Spine1','Chest':'Spine2','Neck':'Neck','Head':'Head'}
for side,s in [('L','Left'),('R','Right')]:
 for t,n in [('Shoulder','Shoulder'),('UpperArm','Arm'),('LowerArm','ForeArm'),('Wrist','Hand'),('UpperLeg','UpLeg'),('LowerLeg','Leg'),('Foot','Foot')]:mapping[t+'.'+side]=s+n
for filename,clip in [('Running.fbx','RunnerRun'),('Jumping Up.fbx','RunnerJump')]:
 before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(pathlib.Path(r'C:\Users\elles\Downloads\runner')/filename));imported=[o for o in bpy.data.objects if o not in before];source=next(o for o in imported if o.type=='ARMATURE');action=source.animation_data.action;start,end=map(int,action.frame_range)
 target.animation_data_create();target.animation_data.action=None
 for b in target.pose.bones:b.matrix_basis=Matrix.Identity(4)
 generated=bpy.data.actions.new(clip);generated.use_fake_user=True;target.animation_data.action=generated
 for frame in range(start,end+1):
  bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();evaluated=source.evaluated_get(bpy.context.evaluated_depsgraph_get())
  pose={}
  for b in target.data.bones:
   rest=b.matrix_local.copy();parent=b.parent;relative=parent.matrix_local.inverted()@rest if parent else rest
   parent_pose=pose[parent.name] if parent else Matrix.Identity(4);location=parent_pose@relative.translation
   src=evaluated.pose.bones.get('mixamorig:'+mapping.get(b.name,''))
   rotation=(parent_pose@relative@finger_pose.get(b.name,Matrix.Identity(4))).to_quaternion()
   if src:
    src_rest=(source.matrix_world@src.bone.matrix_local).to_quaternion();src_pose=(source.matrix_world@src.matrix).to_quaternion();delta=src_pose@src_rest.inverted()
    if clip=='RunnerJump' and b.name in ['Hips','Abdomen','Torso','Chest','Neck','Head']:
     angles=delta.to_euler('XYZ');delta=Euler((max(-.65,min(.65,angles.x)),0,0),'XYZ').to_quaternion()
    rotation=delta@rest.to_quaternion()
   # The Quaternius foot controllers are separate from the leg hierarchy.
   # Move their origin to the animated ankle rather than leaving it on the floor.
   if b.name.startswith('Foot.'):
    leg=target.data.bones['LowerLeg.'+b.name[-1]];location=pose[leg.name]@Vector((0,leg.length,0))
   desired=Matrix.LocRotScale(location,rotation,Vector((1,1,1)))
   basis=relative.inverted()@parent_pose.inverted()@desired
   pb=target.pose.bones[b.name];pb.rotation_mode='QUATERNION';pb.location=basis.to_translation();pb.rotation_quaternion=basis.to_quaternion();pb.scale=Vector((1,1,1))
   for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(data_path=prop,frame=frame-start,group=b.name)
   pose[b.name]=desired
 print('RUNNER_CORRECTED',clip,'frames',end-start+1,'foot_origins_follow_ankles',flush=True)
 for o in imported:bpy.data.objects.remove(o,do_unlink=True)
 for a in list(bpy.data.actions):
  if a!=generated and a.name not in ['RunnerRun','RunnerJump']:bpy.data.actions.remove(a)
bpy.ops.object.select_all(action='DESELECT');target.hide_set(False);target.hide_viewport=False;target.hide_render=False;target.hide_select=False;target.select_set(True);bpy.context.view_layer.objects.active=target
bpy.ops.export_scene.gltf(filepath=str(R/'game/characters/runner_motion.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS')
print('RUNNER_MOTION_CORRECTED',flush=True)
