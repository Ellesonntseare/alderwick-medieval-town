"""Inspect and prepare user-authorized animal downloads; preserve originals."""
import bpy,json,pathlib,shutil
from mathutils import Vector,Matrix
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'game/animals/new';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'source-assets/new-wildlife';SOURCE.mkdir(parents=True,exist_ok=True)
FILES=['cow_idle.glb','horse_basemesh.glb','sheep.glb','sheep-test_non-commercial.glb','birds.glb','model_110a_-_imperial_woodpecker_flying.glb']
records=[]
for filename in FILES:
 path=pathlib.Path(r'C:\Users\elles\Downloads')/filename
 shutil.copy2(path,SOURCE/filename)
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(path))
 meshes=[o for o in bpy.data.objects if o.type=='MESH']
 deps=bpy.context.evaluated_depsgraph_get()
 points=[]
 for obj in meshes:
  evaluated=obj.evaluated_get(deps)
  points.extend(evaluated.matrix_world@v.co for v in evaluated.data.vertices)
 low=Vector([min(p[k] for p in points) for k in range(3)]);high=Vector([max(p[k] for p in points) for k in range(3)])
 record=dict(file=filename,size=list(high-low),meshes=len(meshes),animations=[a.name for a in bpy.data.actions],triangles=sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons))
 for obj in meshes:
  bpy.context.view_layer.objects.active=obj
  if len(obj.data.polygons)>30000 and not obj.data.shape_keys and not any(m.type=='ARMATURE' for m in obj.modifiers):
   modifier=obj.modifiers.new('Wildlife detail budget','DECIMATE');modifier.ratio=30000/len(obj.data.polygons)
   bpy.ops.object.modifier_apply(modifier=modifier.name)
 for image in bpy.data.images:
  if image.size[0]>1024 or image.size[1]>1024:
   ratio=1024/max(image.size);image.scale(max(1,int(image.size[0]*ratio)),max(1,int(image.size[1]*ratio)))
 bpy.ops.export_scene.gltf(filepath=str(OUT/filename),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True)
 # Texture contact sheets are inspection only, not alterations to the assets.
 scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
 scene.display.shading.color_type='TEXTURE';scene.display.shading.light='STUDIO'
 scene.render.resolution_x=800;scene.render.resolution_y=650;scene.render.resolution_percentage=100
 bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera
 centre=(low+high)/2;extent=max(high-low)
 camera.location=centre+Vector((1.3,-1.7,.7))*extent
 camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler()
 camera.data.type='ORTHO';camera.data.ortho_scale=extent*1.3
 scene.render.filepath=str(ROOT/'review'/('wildlife-'+path.stem+'.png'))
 bpy.ops.render.render(write_still=True)
 records.append(record);print('WILDLIFE_PREPARED',json.dumps(record),flush=True)
(OUT/'inspection.json').write_text(json.dumps(records,indent=2))
print('WILDLIFE_PREPARATION_COMPLETE',len(records),flush=True)
