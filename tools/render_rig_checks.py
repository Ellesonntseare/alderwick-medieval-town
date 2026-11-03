import bpy,pathlib,json,sys
from mathutils import Vector
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town')
style=sys.argv[-1] if sys.argv[-1] in ['knight','mercenary','night_hunter','viking'] else 'knight'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(R/'game/characters'/(style+'.glb')))
if not bpy.context.scene.world:bpy.context.scene.world=bpy.data.worlds.new('Rig review')
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.parent==rig];snapshots=[];checks=[]
for i,(clip,frame) in enumerate([('Idle',10),('Walk',10),('SitIdle',10),('SleepExit',0)]):
 action=bpy.data.actions[clip];rig.animation_data.action=action
 if action.slots:rig.animation_data.action_slot=action.slots[0]
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();points=[]
 for o in meshes:
  evaluated=o.evaluated_get(deps);data=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=deps);snap=bpy.data.objects.new(clip+'_'+o.name,data);bpy.context.collection.objects.link(snap);snap.matrix_world=o.matrix_world.copy();snap.location.x+=i*2.3;snapshots.append(snap)
  points.extend([o.matrix_world@v.co for v in data.vertices])
 lo=[min(p[j] for p in points) for j in range(3)];hi=[max(p[j] for p in points) for j in range(3)];checks.append({'clip':clip,'min':lo,'max':hi})
for o in meshes+[rig]:bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.background_type='WORLD';scene.world.color=(.13,.15,.17)
bpy.ops.object.camera_add(location=(3.4,-12,2.6));cam=bpy.context.object;cam.rotation_euler=(Vector((3.4,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=9.8;scene.camera=cam
scene.render.resolution_x=1800;scene.render.resolution_y=650;scene.render.resolution_percentage=100;scene.render.filepath=str(R/(style+'-rig-check.png'));bpy.ops.render.render(write_still=True)
(R/(style+'-rig-check.json')).write_text(json.dumps(checks,indent=2));print('POSE_RENDER_OK',style,flush=True)
