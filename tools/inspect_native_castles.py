import bpy,pathlib,numpy as np,json
from mathutils import Vector
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town');results={}
for name in ['arnstein_castle','feira_castle','castle_xix']:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(R/'game/downloaded'/(name+'.glb')));meshes=[o for o in bpy.data.objects if o.type=='MESH'];points=np.concatenate([np.array([(o.matrix_world@v.co)[:] for v in o.data.vertices]) for o in meshes]);height=points[:,2].max()
 entry={'bounds':[points.min(0).tolist(),points.max(0).tolist()],'slices':{}}
 for threshold in [height*.55,height*.8]:
  q=points[points[:,2]>threshold];entry['slices'][str(round(threshold,2))]={'min':q.min(0).tolist(),'max':q.max(0).tolist(),'median':np.median(q,0).tolist()}
 results[name]=entry
 scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL' if name=='feira_castle' else 'TEXTURE';scene.display.shading.show_cavity=True;scene.world=bpy.data.worlds.new('Review');scene.world.color=(.15,.17,.19)
 # Coordinate grid to locate native entrances and courtyard footprints.
 for axis in range(2):
  for value in range(-30,31,5):
   bpy.ops.object.text_add(location=(value if axis==0 else -30,-30 if axis==0 else value,30))
   text=bpy.context.object;text.data.body=str(value);text.data.size=.8
 bpy.ops.object.camera_add(location=(0,0,80));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=72;scene.camera=cam;scene.render.resolution_x=1300;scene.render.resolution_y=1300;scene.render.resolution_percentage=100;scene.render.filepath=str(R/(name+'-native-plan.png'));bpy.ops.render.render(write_still=True)
 print('NATIVE_CASTLE_LAYOUT',name,json.dumps(entry),flush=True)
(R/'native-castle-layout.json').write_text(json.dumps(results,indent=2))
