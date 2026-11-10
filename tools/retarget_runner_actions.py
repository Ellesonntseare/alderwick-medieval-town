import bpy,pathlib,json,math,sys,zipfile
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
files=list(pathlib.Path('C:/Users/elles/Downloads/runner').rglob('*.fbx'))
runner_model=pathlib.Path('C:/Users/elles/Desktop/Builts/RUSHLINE/Versions/Downloaded-Sources/RUSHLINE-Phase-1-Installer-Repair-v2/RUSHLINE-Phase-1/public/assets/runner/quaternius-animated-human.glb')
jobs=[(next(p for p in files if p.name==filename),clip,None) for filename,clip in [('Falling To Roll.fbx','RunnerRoll'),('Twist Dance.fbx','RunnerDance')]]
jobs.extend([(runner_model,'RunnerWorking','Working'),(runner_model,'RunnerPunch','Punch')])
jobs.extend([(pathlib.Path(r'C:\Users\elles\Downloads')/filename,clip,None) for filename,clip in [('Sitting And Pointing.fbx','SitPoint'),('Pick Fruit.fbx','PickFruit')] if (pathlib.Path(r'C:\Users\elles\Downloads')/filename).exists()])
jobs.extend([(pathlib.Path(r'C:\Users\elles\Downloads')/'Draw Sword 1.fbx','DrawSword',None)] if pathlib.Path(r'C:\Users\elles\Downloads\Draw Sword 1.fbx').exists() else [])
extras='--extras' in sys.argv
if extras:jobs=[(pathlib.Path(r'C:\Users\elles\Downloads')/name,clip,None) for name,clip in [('bow and arrow Standing Draw Arrow.fbx','DrawArrow'),('Standing Aim Overdraw.fbx','AimOverdraw'),('Standing Idle 03 Examine.fbx','Examine')]]
exported=[]
equipment='--equipment' in sys.argv
farming='--farming' in sys.argv
locomotion='--locomotion' in sys.argv
social='--social' in sys.argv
remaining='--remaining-actions' in sys.argv
if equipment:
 jobs=[(pathlib.Path.home()/'Downloads'/name,clip,None) for name,clip in [
  ('Sword And Shield Idle.fbx','ShieldIdle'),('Sword And Shield Kick.fbx','ShieldKick'),
  ('Defeated.fbx','Defeated'),('Dig And Plant Seeds.fbx','DigPlant'),
  ('Action Idle To Standing Idle.fbx','ActionToIdle'),('Waving Gesture.fbx','WaveGesture'),
  ('Wheelbarrow Walk.fbx','WheelbarrowWalk'),('Female Walk.fbx','FemaleWalk'),
  ('Male Action Pose.fbx','ActionPose'),('Drunk Idle Variation.fbx','DrunkIdle'),('Sitting.fbx','SittingPose')]]
if equipment:
 folder=R/'source-assets/shield-animation-review'
 folder.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(pathlib.Path.home()/'Downloads'/'Sword and Shield Pack.zip') as pack:
  for name,clip in [('sword and shield block.fbx','ShieldBlock'),('sword and shield block idle.fbx','ShieldBlockHold'),('sword and shield slash.fbx','ShieldSlash')]:
   source_path=folder/name
   source_path.write_bytes(pack.read(name))
   jobs.append((source_path,clip,None))
if farming:
 folder=R/'source-assets/farming-animation-review'
 folder.mkdir(parents=True,exist_ok=True)
 jobs=[]
 with zipfile.ZipFile(pathlib.Path.home()/'Downloads'/'Farming Pack.zip') as pack:
  if pack.testzip() is not None:raise ValueError('Farming Pack failed its archive integrity check')
  for name,clip in [('pull plant.fbx','PullPlant'),('box idle.fbx','BoxIdle'),('holding walk.fbx','BoxWalk')]:
   source_path=folder/name
   source_path.write_bytes(pack.read(name))
   jobs.append((source_path,clip,None))
 jobs.extend((pathlib.Path.home()/'Downloads'/name,clip,None) for name,clip in [('Picking Up.fbx','PickUp'),('Working On Device.fbx','WorkDevice')])
if locomotion:
 folder=R/'source-assets/locomotion-animation-review'
 folder.mkdir(parents=True,exist_ok=True)
 jobs=[]
 with zipfile.ZipFile(pathlib.Path.home()/'Downloads'/'Basic Locomotion Pack.zip') as pack:
  if pack.testzip() is not None:raise ValueError('Basic Locomotion Pack failed its archive integrity check')
  for name in pack.namelist():
   if '/' in name or '\\' in name or not name.lower().endswith('.fbx'):continue
   source_path=folder/name
   source_path.write_bytes(pack.read(name))
   clip='Basic'+''.join(word.capitalize() for word in source_path.stem.split())
   jobs.append((source_path,clip,None))
if social:
 folder=R/'source-assets/social-animation-review'
 folder.mkdir(parents=True,exist_ok=True)
 jobs=[]
 for name,clip in [('Jazz Dancing.fbx','JazzDance'),('Shaking Head No.fbx','HeadShakeNo')]:
  original=pathlib.Path.home()/'Downloads'/name
  source_path=folder/name
  source_path.write_bytes(original.read_bytes())
  jobs.append((source_path,clip,None))
if remaining:
 jobs=[(pathlib.Path.home()/'Downloads'/name,clip,None) for name,clip in [
  ('Carrying Turn.fbx','CarryingTurn'),('Carrying.fbx','CarryingIdle'),
  ('Shove Reaction.fbx','ShoveReaction'),('Drunk Walk Backwards.fbx','DrunkWalkBackwards'),
  ('Singing.fbx','Singing'),('Praying.fbx','Praying')]]
for filepath,clip,source_clip in jobs:
 before=set(bpy.data.objects)
 if filepath.suffix.lower()=='.fbx':bpy.ops.import_scene.fbx(filepath=str(filepath))
 else:bpy.ops.import_scene.gltf(filepath=str(filepath))
 imported=[o for o in bpy.data.objects if o not in before];source=next(o for o in imported if o.type=='ARMATURE')
 source_bones={b.name.split(':')[-1]:b for b in source.pose.bones}
 if source_clip:
  track=next(t for t in source.animation_data.nla_tracks if source_clip.lower() in t.name.lower())
  source.animation_data.action=track.strips[0].action
  for t in source.animation_data.nla_tracks:t.mute=True
 action=source.animation_data.action;start,end=map(int,action.frame_range)

 target.animation_data_create();target.animation_data.action=None
 for b in target.pose.bones:b.matrix_basis=Matrix.Identity(4)
 generated=bpy.data.actions.new(clip);generated.use_fake_user=True;target.animation_data.action=generated
 for frame in range(start,end+1):
  bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();evaluated=source.evaluated_get(bpy.context.evaluated_depsgraph_get())
  pose={}
  for b in target.data.bones:
   rest=b.matrix_local.copy();parent=b.parent;relative=parent.matrix_local.inverted()@rest if parent else rest
   parent_pose=pose[parent.name] if parent else Matrix.Identity(4);location=parent_pose@relative.translation
   source_bone=source_bones.get(mapping.get(b.name,''))
   src=evaluated.pose.bones.get(source_bone.name) if source_bone else None
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
  if clip in {'DigPlant','RunnerWorking','ShieldIdle','ShieldKick','ShieldBlock','ShieldBlockHold','ShieldSlash','ActionPose'}:
   foot_rest=min(target.data.bones['Foot.'+side].head_local.z for side in ['L','R'])
   foot_pose=min(pose['Foot.'+side].translation.z for side in ['L','R'])
   root=target.pose.bones['Root']
   root.location+=root.bone.matrix_local.to_3x3().inverted()@Vector((0,0,foot_rest-foot_pose))
   root.keyframe_insert(data_path='location',frame=frame-start,group='Root')
 print('RUNNER_CORRECTED',clip,'frames',end-start+1,'foot_origins_follow_ankles',flush=True)
 exported.append(clip)
 for o in imported:bpy.data.objects.remove(o,do_unlink=True)
 for a in list(bpy.data.actions):
  if a!=generated and a.name not in exported:bpy.data.actions.remove(a)
bpy.ops.object.select_all(action='DESELECT');target.hide_set(False);target.hide_viewport=False;target.hide_render=False;target.hide_select=False;target.select_set(True);bpy.context.view_layer.objects.active=target
output='social_actions' if social else 'basic_locomotion' if locomotion else 'farming_actions' if farming else 'equipment_actions' if equipment else 'runner_extra_actions' if extras else 'runner_actions'
destination=R/'review/remaining_actions.glb' if remaining else R/'game/characters'/(output+'.glb')
bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS')
print('RUNNER_MOTION_CORRECTED',flush=True)
