"""Add gentle in-place quadruped walk cycles; retain user source assets."""
import bpy,math,pathlib,json,sys,statistics
from mathutils import Vector,Matrix,Quaternion
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'game/animals/new'
report=[]

def simple_quadruped(meshes,height,repair_hooves=False):
 points=[]
 for mesh in meshes:
  matrix=mesh.matrix_world.copy();mesh.parent=None;mesh.data.transform(matrix);mesh.matrix_world=Matrix.Identity(4)
  for modifier in list(mesh.modifiers):mesh.modifiers.remove(modifier)
  mesh.vertex_groups.clear()
  points.extend(v.co.copy() for v in mesh.data.vertices)
 low=Vector([min(p[k] for p in points) for k in range(3)]);high=Vector([max(p[k] for p in points) for k in range(3)])
 centre=(low+high)/2;factor=height/(high.z-low.z)
 for mesh in meshes:
  for vertex in mesh.data.vertices:vertex.co=Vector(((vertex.co.x-centre.x)*factor,(vertex.co.y-centre.y)*factor,(vertex.co.z-low.z)*factor))
 if repair_hooves:
  # The source's foot controls stretched the lowest vertices sideways. Keep
  # the fleece/body unchanged, restoring compact hooves beneath each shin.
  columns={}
  for front in [True,False]:
   for side in [-1,1]:
    band=[v.co for mesh in meshes for v in mesh.data.vertices if height*.17<v.co.z<height*.34 and v.co.x*side>0 and (v.co.y<0)==front]
    if band:columns[(front,side)]=Vector((statistics.median(v.x for v in band),statistics.median(v.y for v in band),0))
  for mesh in meshes:
   for vertex in mesh.data.vertices:
    if vertex.co.z>=height*.31:continue
    key=(vertex.co.y<0,1 if vertex.co.x>0 else -1)
    if key not in columns:continue
    column=columns[key];offset=Vector((vertex.co.x-column.x,vertex.co.y-column.y,0))
    if offset.length>height*.055:
     repaired=column+offset.normalized()*height*.055
     blend=max(0,min(1,(height*.31-vertex.co.z)/(height*.12)))
     vertex.co.x=vertex.co.x*(1-blend)+repaired.x*blend;vertex.co.y=vertex.co.y*(1-blend)+repaired.y*blend
 bpy.ops.object.armature_add();armature=bpy.context.object;armature.name='CleanQuadrupedRig'
 bpy.ops.object.mode_set(mode='EDIT');armature.data.edit_bones.remove(armature.data.edit_bones[0])
 body=armature.data.edit_bones.new('Body');body.head=(0,0,height*.58);body.tail=(0,-height*.15,height*.73)
 feet={}
 for front in [True,False]:
  for side in [-1,1]:
   label=('Front' if front else 'Back')+('.L' if side>0 else '.R')
   vertices=[v.co for mesh in meshes for v in mesh.data.vertices if v.co.z<height*.15 and v.co.x*side>0 and (v.co.y<0)==front]
   foot=sum(vertices,Vector())/len(vertices) if vertices else Vector((side*height*.1,(-1 if front else 1)*height*.3,.02))
   feet[label]=foot
   upper=armature.data.edit_bones.new(label+'Upper');upper.head=(foot.x,foot.y,height*.55);upper.tail=(foot.x,foot.y,height*.27);upper.parent=body
   lower=armature.data.edit_bones.new(label+'Lower');lower.head=upper.tail;lower.tail=(foot.x,foot.y,.02);lower.parent=upper;lower.use_connect=True
 bpy.ops.object.mode_set(mode='OBJECT')
 for mesh in meshes:
  for bone in armature.data.bones:mesh.vertex_groups.new(name=bone.name)
  for vertex in mesh.data.vertices:
   label=min(feet,key=lambda k:math.hypot(vertex.co.x-feet[k].x,vertex.co.y-feet[k].y))
   distance=math.hypot(vertex.co.x-feet[label].x,vertex.co.y-feet[label].y)
   leg=max(0,min(1,(height*.61-vertex.co.z)/(height*.11)))*max(0,min(1,(height*.22-distance)/(height*.09)))
   lower=max(0,min(1,(height*.34-vertex.co.z)/(height*.12)))
   for name,weight in [('Body',1-leg),(label+'Upper',leg*(1-lower)),(label+'Lower',leg*lower)]:
    if weight>0:mesh.vertex_groups[name].add([vertex.index],weight,'REPLACE')
  modifier=mesh.modifiers.new('Clean quadruped skin','ARMATURE');modifier.object=armature;mesh.parent=armature
 return armature

files=['sheep-test_non-commercial.glb'] if '--sheep-only' in sys.argv else ['cow_idle.glb','horse_basemesh.glb','sheep.glb','sheep-test_non-commercial.glb']
for filename in files:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'source-assets/new-wildlife'/filename))
 for obj in list(bpy.data.objects):
  if obj.type=='MESH' and obj.name.startswith('Icosphere') and len(obj.data.vertices)<100:bpy.data.objects.remove(obj,do_unlink=True)
 scene=bpy.context.scene;scene.frame_set(scene.frame_start)
 arms=[o for o in bpy.data.objects if o.type=='ARMATURE']
 if not arms:
  obj=next(o for o in bpy.data.objects if o.type=='MESH')
  obj.data.transform(obj.matrix_world);obj.parent=None;obj.matrix_world=Matrix.Identity(4)
  points=[v.co.copy() for v in obj.data.vertices]
  low=Vector([min(p[k] for p in points) for k in range(3)]);high=Vector([max(p[k] for p in points) for k in range(3)])
  scale=1.65/(high.z-low.z);centre=(low+high)/2
  for v in obj.data.vertices:v.co=Vector(((v.co.x-centre.x)*scale,(v.co.y-centre.y)*scale,(v.co.z-low.z)*scale))
  bpy.ops.object.armature_add();arm=bpy.context.object;arm.name='HorseWalkingRig'
  bpy.ops.object.mode_set(mode='EDIT');arm.data.edit_bones.remove(arm.data.edit_bones[0])
  body=arm.data.edit_bones.new('Body');body.head=(0,0,.95);body.tail=(0,-.25,1.2)
  centres={}
  for front in [True,False]:
   for side in [-1,1]:
    label=('Front' if front else 'Back')+('.L' if side>0 else '.R')
    feet=[v.co for v in obj.data.vertices if v.co.z<.25 and v.co.x*side>0 and (v.co.y<0)==front]
    centrefoot=sum(feet,Vector())/len(feet) if feet else Vector((side*.15,-.5 if front else .5,.03))
    centres[label]=centrefoot
    upper=arm.data.edit_bones.new(label+'Upper');upper.head=(centrefoot.x,centrefoot.y,.90);upper.tail=(centrefoot.x,centrefoot.y,.43);upper.parent=body
    lower=arm.data.edit_bones.new(label+'Lower');lower.head=upper.tail;lower.tail=(centrefoot.x,centrefoot.y,.035);lower.parent=upper;lower.use_connect=True
  bpy.ops.object.mode_set(mode='OBJECT')
  for bone in arm.data.bones:obj.vertex_groups.new(name=bone.name)
  for vertex in obj.data.vertices:
   label=min(centres,key=lambda k:(Vector((vertex.co.x,vertex.co.y,0))-Vector((centres[k].x,centres[k].y,0))).length)
   distance=(Vector((vertex.co.x,vertex.co.y,0))-Vector((centres[label].x,centres[label].y,0))).length
   leg=max(0,min(1,(.96-vertex.co.z)/.18))*max(0,min(1,(.32-distance)/.12))
   lower=max(0,min(1,(.56-vertex.co.z)/.20))
   for name,weight in [('Body',1-leg),(label+'Upper',leg*(1-lower)),(label+'Lower',leg*lower)]:
    if weight>0:obj.vertex_groups[name].add([vertex.index],weight,'REPLACE')
  modifier=obj.modifiers.new('Quadruped skin','ARMATURE');modifier.object=arm
  obj.parent=arm
 else:arm=arms[0]
 if filename=='sheep-test_non-commercial.glb':
  # This scan has large inherited bind offsets and control/end bones. Bake
  # its valid visible idle pose into the rest mesh before authoring a gait;
  # retain the deform groups, not the incompatible imported control motion.
  deps=bpy.context.evaluated_depsgraph_get()
  for mesh in [o for o in bpy.data.objects if o.type=='MESH']:
   evaluated=mesh.evaluated_get(deps)
   mesh.data=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=deps)
  for obj in bpy.data.objects:
   if obj.animation_data:obj.animation_data_clear()
  bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);bpy.context.view_layer.objects.active=arm
  bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT')
  meshes=[o for o in bpy.data.objects if o.type=='MESH']
  old_arm=arm
  arm=simple_quadruped(meshes,.82,repair_hooves=True)
  bpy.data.objects.remove(old_arm,do_unlink=True)
  for action in list(bpy.data.actions):bpy.data.actions.remove(action)
 # The downloaded pose establishes the unchanged body and limb rest shape.
 bpy.context.view_layer.update()
 base={p.name:(p.location.copy(),p.rotation_quaternion.copy(),p.scale.copy()) for p in arm.pose.bones}
 world_axis=arm.matrix_world.to_3x3().inverted()@Vector((1,0,0))
 axes={p.name:p.matrix.to_3x3().inverted()@world_axis for p in arm.pose.bones}
 feet=[]
 for foot in arm.pose.bones:
  label=foot.name.lower()
  if 'foot' not in label or '_end' in label:continue
  front='front' in label;side='.l' if '.l' in label else '.r'
  lowers=[p for p in arm.pose.bones if ('front' in p.name.lower())==front and side in p.name.lower() and ('lowleg' in p.name.lower() or 'lowerleg' in p.name.lower()) and '_end' not in p.name.lower()]
  if lowers:feet.append((foot,lowers[0],foot.matrix.copy(),lowers[0].tail.copy()))
 original=arm.animation_data.action if arm.animation_data else None
 if original:original.name='Idle'
 arm.animation_data_create()
 if original:
  track=arm.animation_data.nla_tracks.new();track.name='Idle';track.strips.new('Idle',1,original)
 walk=bpy.data.actions.new('Walk');arm.animation_data.action=walk
 swing_names=[]
 for frame in range(1,34,2):
  phase=(frame-1)/32*math.tau
  for pose in arm.pose.bones:
   loc,rotation,size=base[pose.name];pose.rotation_mode='QUATERNION';pose.location=loc;pose.rotation_quaternion=rotation;pose.scale=size
   name=pose.name.lower()
   upper=('upleg' in name or 'upperleg' in name or name.endswith('upper')) and ('front' in name or 'back' in name) and '_end' not in name
   lower=('lowleg' in name or 'lowerleg' in name or name.endswith('lower')) and ('front' in name or 'back' in name) and '_end' not in name
   if upper or lower:
    offset=0 if 'front' in name and '.l' in name else math.pi/2 if 'back' in name and '.r' in name else math.pi if 'front' in name else math.pi*1.5
    wave=math.sin(phase+offset)
    amplitude=.19 if filename.startswith('sheep') else .26
    angle=amplitude*wave if upper else -amplitude*1.2*max(0,math.sin(phase+offset+.7))
    pose.rotation_quaternion=rotation@Quaternion(axes[pose.name].normalized(),angle)
    if pose.name not in swing_names:swing_names.append(pose.name)
  bpy.context.view_layer.update()
  for foot,lower,rest_matrix,rest_tail in feet:
   current=rest_matrix.copy();current.translation+=lower.tail-rest_tail;foot.matrix=current
  for pose in arm.pose.bones:
   pose.keyframe_insert('location',frame=frame);pose.keyframe_insert('rotation_quaternion',frame=frame);pose.keyframe_insert('scale',frame=frame)
 scene.frame_end=33
 if not original:
  idle=bpy.data.actions.new('Idle');arm.animation_data.action=idle
  for pose in arm.pose.bones:
   loc,rotation,size=base[pose.name];pose.location=loc;pose.rotation_quaternion=rotation;pose.scale=size
   for frame in [1,33]:
    pose.keyframe_insert('location',frame=frame);pose.keyframe_insert('rotation_quaternion',frame=frame);pose.keyframe_insert('scale',frame=frame)
  track=arm.animation_data.nla_tracks.new();track.name='Idle';track.strips.new('Idle',1,idle)
 arm.animation_data.action=walk
 # Mute NLA evaluation while the active walk action is sampled.
 for track in arm.animation_data.nla_tracks:track.mute=True
 bpy.ops.export_scene.gltf(filepath=str(OUT/filename),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True)
 report.append(dict(file=filename,walking_bones=swing_names,following_foot_controls=len(feet),clips=['Idle','Walk']))
 print('FARM_ANIMAL_WALK',filename,len(swing_names),flush=True)
(OUT/'walking-rigs.json').write_text(json.dumps(report,indent=2))
