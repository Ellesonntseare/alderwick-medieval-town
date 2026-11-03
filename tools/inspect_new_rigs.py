import bpy,pathlib,json
from mathutils import Vector
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town')
bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/all-together/All together/Blends/All together.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
print('BONES',json.dumps({b.name:[list(rig.matrix_world@b.head_local),list(rig.matrix_world@b.tail_local)] for b in rig.data.bones}),flush=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
files=['knight_with_spear_and_shield.glb','blood_moor_mercenary_diablo_2_inspired_art.glb','night_hunter_assassin_-_dark_fantasy.glb','gart220_female_viking.glb']
for i,n in enumerate(files):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(pathlib.Path(r'C:\Users\elles\Downloads')/n));objs=[o for o in bpy.data.objects if o not in before];meshes=[o for o in objs if o.type=='MESH']
 pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];lo=Vector(tuple(min(p[j] for p in pts) for j in range(3)));hi=Vector(tuple(max(p[j] for p in pts) for j in range(3)))
 print('MODEL',n,'bounds',list(lo),list(hi),'parts',[(o.name,len(o.data.vertices)) for o in meshes],flush=True)
 scale=2/(hi.z-lo.z);center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
 for o in meshes:
  mat=o.matrix_world.copy();o.parent=None;o.matrix_world=mat
  for v in o.data.vertices:v.co=(mat@v.co-center)*scale+Vector((i*2.4,0,0))
  o.matrix_world.identity()
 for o in objs:
  if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True
scene.world.color=(0.15,0.15,0.15)
bpy.ops.object.camera_add(location=(3.6,-12,1.2));cam=bpy.context.object;cam.rotation_euler=(Vector((3.6,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=10.2;scene.camera=cam
scene.render.resolution_x=1800;scene.render.resolution_y=600;scene.render.resolution_percentage=100;scene.render.filepath=str(R/'characters-before-rig.png');bpy.ops.render.render(write_still=True)
