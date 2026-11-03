import bpy, pathlib, math, json, sys, numpy as np
from mathutils import Vector, Matrix
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town'); D=pathlib.Path(r'C:\Users\elles\Downloads'); OUT=R/'game/characters'; WORK=R/'source-assets/rigged-characters'; WORK.mkdir(exist_ok=True)
CONFIG=[('knight_with_spear_and_shield.glb','knight',[(.22,0,1.43),(.43,-.02,1.22),(.61,-.04,1.04)]),('blood_moor_mercenary_diablo_2_inspired_art.glb','mercenary',[(.20,0,1.43),(.28,-.06,1.16),(.12,-.25,1.06)]),('night_hunter_assassin_-_dark_fantasy.glb','night_hunter',[(.21,0,1.40),(.28,-.02,1.11),(.32,-.04,.84)]),('gart220_female_viking.glb','viking',[(.20,0,1.46),(.36,-.015,1.29),(.50,-.02,1.12)])]
ONLY=sys.argv[-1] if '--' in sys.argv else ''
REPORT=json.loads((R/'rigged-character-report.json').read_text()) if ONLY else []
CORE=['Root','Body','Hips','Abdomen','Torso','Chest','Neck','Head']+[n+'.'+s for s in ['L','R'] for n in ['Shoulder','UpperArm','LowerArm','Wrist','UpperLeg','LowerLeg','Foot']]
for filename,style,arm in CONFIG:
 if ONLY and style!=ONLY:continue
 REPORT=[r for r in REPORT if r['style']!=style]
 bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/all-together/All together/Blends/All together.blend'))
 source=next(o for o in bpy.data.objects if o.type=='ARMATURE'); source.name='MotionSource'
 source.animation_data_clear()
 for o in list(bpy.data.objects):
  if o!=source:bpy.data.objects.remove(o,do_unlink=True)
 clips={n:bpy.data.actions['Idle_Neutral' if n=='Idle' else n] for n in ['Idle','Walk','Run','Interact','Wave']}
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(R/'game/characters/daily_motion.glb'))
 daily_objects=[o for o in bpy.data.objects if o not in before]; daily=next(o for o in daily_objects if o.type=='ARMATURE')
 for a in bpy.data.actions:
  if a.name in ['SitEnter','SitIdle','SitExit','WorkTable','SleepExit','WorkHarvest']:clips[a.name]=a
 # Daily clips use the same source rig; retain their action slots, binding them below.
 for o in daily_objects:bpy.data.objects.remove(o,do_unlink=True)
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(D/filename)); imported=[o for o in bpy.data.objects if o not in before]; meshes=[o for o in imported if o.type=='MESH']
 for o in list(meshes):
  if any(x in o.name.lower() for x in ['floor','rock_','gold_gold']):meshes.remove(o);bpy.data.objects.remove(o,do_unlink=True)
 for o in meshes:
  world=o.matrix_world.copy();o.parent=None;o.data=o.data.copy();o.data.transform(world);o.matrix_world=Matrix.Identity(4)
  for m in list(o.modifiers):o.modifiers.remove(m)
 pts=np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in meshes]); low=pts.min(0);high=pts.max(0);height=high[2]-low[2]
 heads=pts[pts[:,2]>low[2]+height*.86]; center=np.array([np.median(heads[:,0]),(np.quantile(heads[:,1],.1)+np.quantile(heads[:,1],.9))/2,low[2]])
 ratio=1.8/height
 for o in meshes:
  for v in o.data.vertices:v.co=Vector((np.array(v.co[:])-center)*ratio)
 # Weld artificial chunk borders before reducing the dense generated model.
 if style=='night_hunter':
  import bmesh
  bpy.ops.object.select_all(action='DESELECT')
  for o in meshes:o.select_set(True)
  bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();meshes=[bpy.context.object]
  bm=bmesh.new();bm.from_mesh(meshes[0].data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.00003);bm.to_mesh(meshes[0].data);bm.free()
 total=sum(len(o.data.polygons) for o in meshes);budget=65000
 for o in meshes:
  if total>budget and len(o.data.polygons)>200:
   bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Town mesh budget','DECIMATE');mod.ratio=budget/total;bpy.ops.object.modifier_apply(modifier=mod.name)
 for image in bpy.data.images:
  if image.size[0] and max(image.size)>1024:
   f=1024/max(image.size);image.scale(max(1,round(image.size[0]*f)),max(1,round(image.size[1]*f)))
 # Move separately supplied knight equipment into a carried position before binding.
 rigid={}
 if style=='knight':
  for o in meshes:
   p=np.array([v.co[:] for v in o.data.vertices]);lo=p.min(0);hi=p.max(0);mid=(lo+hi)/2
   if mid[0]>.75:
    shift=Vector((arm[-1][0]-.03,-.16,1.0))-Vector(mid);o.data.transform(Matrix.Translation(shift));rigid[o.name]='LowerArm.L'
   elif mid[0]<-.65 and hi[2]-lo[2]>1.0:
    # Upright spear is strapped to the back while moving through town.
    shift=Vector((-.24,.15,.95))-Vector(mid);o.data.transform(Matrix.Translation(shift));rigid[o.name]='Chest'
 if style=='viking':
  # The small separate mesh contains both hands, not the carried weapon.
  import bmesh
  body=next(o for o in meshes if o.name.startswith('Object_2'))
  bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table();bm.verts.index_update()
  selected={v for v in bm.verts if v.co.x<-.53};queue=list(selected)
  while queue:
   for edge in queue.pop().link_edges:
    for neighbor in edge.verts:
     if neighbor not in selected:selected.add(neighbor);queue.append(neighbor)
  ids={v.index for v in selected};assert 0<len(ids)<len(bm.verts)*.4,('Shield component',len(ids),len(bm.verts))
  shield_bm=bm.copy();shield_bm.verts.ensure_lookup_table();shield_bm.verts.index_update()
  bmesh.ops.delete(shield_bm,geom=[v for v in shield_bm.verts if v.index not in ids],context='VERTS')
  shield_mesh=bpy.data.meshes.new('Viking_Shield_Geometry');shield_bm.to_mesh(shield_mesh);shield_bm.free()
  for material in body.data.materials:shield_mesh.materials.append(material)
  bmesh.ops.delete(bm,geom=list(selected),context='VERTS');bm.to_mesh(body.data);bm.free()
  shield=bpy.data.objects.new('Equipment_Shield',shield_mesh);bpy.context.collection.objects.link(shield);meshes.append(shield);rigid[shield.name]='LowerArm.R'
  points=np.array([v.co[:] for v in shield_mesh.vertices]);centre=Vector((points.min(0)+points.max(0))/2)
  rotate=Matrix.Rotation(-math.pi/2,4,'Z');destination=Vector((-.55,-.20,1.02))
  for vertex in shield_mesh.vertices:vertex.co=rotate.to_3x3()@(vertex.co-centre)+destination
  assert len(shield_mesh.polygons)>50,('Missing shield faces',len(shield_mesh.polygons))
  print('VIKING_SHIELD_SEPARATED',len(shield_mesh.vertices),len(shield_mesh.polygons),flush=True)
 if style=='mercenary':
  for o in meshes:
   if o.name.lower().startswith(('bag_','belt_','dagger_','ear_')):rigid[o.name]='Hips'
 # Keep the source hierarchy and bone names so all existing gameplay poses work.
 data=bpy.data.armatures.new(style+'_skeleton');rig=bpy.data.objects.new('CharacterArmature',data);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 points={'Root':((0,0,0),(0,0,.12)),'Body':((0,0,.96),(0,0,1.10)),'Hips':((0,0,.96),(0,0,1.08)),'Abdomen':((0,0,1.08),(0,0,1.23)),'Torso':((0,0,1.23),(0,0,1.36)),'Chest':((0,0,1.36),(0,0,1.49)),'Neck':((0,0,1.49),(0,0,1.57)),'Head':((0,0,1.57),(0,0,1.79))}
 for side,sign in [('L',1),('R',-1)]:
  foot_points=np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in meshes])
  foot_points=foot_points[(foot_points[:,2]<.19)&(foot_points[:,0]*sign>.035)]
  ankle_x=max(.085,min(.24,float(np.median(foot_points[:,0]*sign)))) if len(foot_points) else .115
  shoulder,elbow,wrist=[Vector((p[0]*sign,p[1],p[2])) for p in arm];hand=wrist+(wrist-elbow).normalized()*.10
  for n,h,t in [('Shoulder',Vector((.07*sign,0,1.39)),shoulder),('UpperArm',shoulder,elbow),('LowerArm',elbow,wrist),('Wrist',wrist,hand),('UpperLeg',Vector((ankle_x*.8*sign,0,.96)),Vector((ankle_x*sign,-.01,.52))),('LowerLeg',Vector((ankle_x*sign,-.01,.52)),Vector((ankle_x*sign,0,.10))),('Foot',Vector((ankle_x*sign,0,.10)),Vector((ankle_x*sign,-.20,.08)))]:points[n+'.'+side]=(h,t)
 for name in CORE:
  b=data.edit_bones.new(name);b.head=points[name][0];b.tail=points[name][1];b.use_deform=name not in ['Root','Body']
  sb=source.data.bones[name];parent=sb.parent
  while parent and parent.name not in CORE:parent=parent.parent
  if name.startswith('Foot.'):b.parent=data.edit_bones['LowerLeg.'+name[-1]]
  elif parent:b.parent=data.edit_bones[parent.name]
  b.align_roll(sb.matrix_local.to_3x3().col[2])
 bpy.ops.object.mode_set(mode='OBJECT')
 deform=[b for b in data.bones if b.use_deform];names=[b.name for b in deform];a=np.array([b.head_local[:] for b in deform]);z=np.array([b.tail_local[:] for b in deform]);v=z-a;vv=np.sum(v*v,axis=1)
 for o in meshes:
  o.vertex_groups.clear();groups=[o.vertex_groups.new(name=n) for n in names];p=np.array([q.co[:] for q in o.data.vertices]);t=np.clip(np.sum((p[:,None,:]-a)*v,axis=2)/vv,0,1);near=a[None,:,:]+t[:,:,None]*v;dist=np.sum((p[:,None,:]-near)**2,axis=2)
  # Anatomical partitions stop lowered hands taking vertices from the hips.
  for j,n in enumerate(names):
   if 'Arm.' in n or 'Wrist.' in n or 'Shoulder.' in n:
    sign=1 if n.endswith('.L') else -1
    dist[:,j]+=np.where(p[:,0]*sign<.13,.3,0)+np.where(p[:,2]<.70,1,0)
   if 'Leg.' in n or 'Foot.' in n:dist[:,j]+=np.where(p[:,2]>1.06,1,0)
  # Torso vertices must not follow a nearby elbow or hand in a posed source mesh.
  core=(np.abs(p[:,0])<.21)&(p[:,2]>.88)&(p[:,2]<1.52)
  if style=='mercenary' and 'gloves_' in o.name.lower():core[:]=False
  for j,n in enumerate(names):
   if any(t in n for t in ['Arm.','Wrist.','Leg.','Foot.']):dist[:,j]+=np.where(core,2.0,0)
  idx=np.argsort(dist,axis=1)[:,:3];selected=np.take_along_axis(dist,idx,axis=1);weights=1/np.maximum(selected,.00025)**2.5;weights/=weights.sum(1,keepdims=True)
  if o.name in rigid:
   groups[names.index(rigid[o.name])].add(list(range(len(p))),1,'REPLACE')
  else:
   for k in range(len(p)):
    # Keep the face and hood solid; do not blend them into the shoulders.
    if p[k,2]>1.56 and abs(p[k,0])<.24:
     groups[names.index('Head')].add([k],1,'REPLACE');continue
    if (style=='mercenary' and 'gloves_' in o.name.lower()) or (style=='viking' and o.name.startswith('Object_4')):
     groups[names.index('Wrist.'+('L' if p[k,0]>0 else 'R'))].add([k],1,'REPLACE');continue
    # A long skirt hangs from the hips instead of being pulled into the knees.
    if style=='viking' and o.name.startswith('Object_3') and .25<p[k,2]<.90 and abs(p[k,0])<.35:
     groups[names.index('Hips')].add([k],1,'REPLACE');continue
    for j,w in zip(idx[k],weights[k]):
     if w>.005:groups[int(j)].add([k],float(w),'REPLACE')
  mod=o.modifiers.new('Town skeletal deformation','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True;o.parent=rig
  assert all(len(q.groups)>0 for q in o.data.vertices),o.name
 # Retarget evaluated source transforms and write local channels directly.
 baked=[]
 for name,action in clips.items():
  for b in source.pose.bones:
   b.matrix_basis=Matrix.Identity(4)
   for c in b.constraints:c.mute=name not in ['Idle','Walk','Run','Interact','Wave']
  source.animation_data_create();source.animation_data.action=action
  if action.slots:source.animation_data.action_slot=action.slots[0]
  rig.animation_data_create();output=bpy.data.actions.new('Baked_'+name);rig.animation_data.action=output
  start,end=map(int,action.frame_range);bpy.context.scene.render.fps=30
  print('BAKING_START',style,name,start,end,flush=True)
  for frame in range(start,end+1):
   bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
   evaluated=source.evaluated_get(bpy.context.evaluated_depsgraph_get())
   rotations={n:evaluated.pose.bones[n].matrix.copy().to_quaternion() for n in CORE}
   offsets={n:evaluated.pose.bones[n].location.copy() for n in ['Root','Body']}
   pose={}
   for n in CORE:
    rest=data.bones[n];parent=rest.parent
    relative=parent.matrix_local.inverted()@rest.matrix_local if parent else rest.matrix_local.copy()
    parent_pose=pose[parent.name] if parent else Matrix.Identity(4)
    location=parent_pose@relative.translation
    if n in offsets:location+=offsets[n]*.95
    rotation=rotations[n]
    if style=='mercenary' and n.startswith(('Shoulder.','UpperArm.','LowerArm.','Wrist.')):
     rotation=(parent_pose@relative).to_quaternion()
    desired=Matrix.LocRotScale(location,rotation,Vector((1,1,1)))
    basis=relative.inverted()@parent_pose.inverted()@desired
    b=rig.pose.bones[n];b.rotation_mode='QUATERNION';b.location=basis.to_translation();b.rotation_quaternion=basis.to_quaternion()
    b.keyframe_insert(data_path='rotation_quaternion',frame=frame-start,group=n);b.keyframe_insert(data_path='location',frame=frame-start,group=n)
    pose[n]=desired
  baked.append((name,output));print('RIG_CLIP',style,name,end-start+1,flush=True)
 for action in list(bpy.data.actions):
  if action not in [a for n,a in baked]:bpy.data.actions.remove(action)
 for name,action in baked:action.name=name;action.use_fake_user=True
 bpy.data.objects.remove(source,do_unlink=True)
 for o in list(bpy.data.objects):
  if o not in meshes and o!=rig:bpy.data.objects.remove(o,do_unlink=True)
 rig.animation_data.action=baked[0][1];bpy.context.scene.frame_set(0)
 bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True)
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.wm.save_as_mainfile(filepath=str(WORK/(style+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(style+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_materials='EXPORT')
 REPORT.append({'source':filename,'style':style,'bones':len(data.bones),'vertices':sum(len(o.data.vertices) for o in meshes),'clips':[n for n,a in baked],'weighted_vertices':True,'rigid_equipment':rigid})
 (R/'rigged-character-report.json').write_text(json.dumps(REPORT,indent=2));print('CHARACTER_RIGGED',style,flush=True)
print('RIGGING_FINISHED',len(REPORT),flush=True)
