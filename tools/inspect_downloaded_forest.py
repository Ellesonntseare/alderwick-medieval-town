import bpy,pathlib,json,numpy as np
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'C:\Users\elles\Downloads\a_forest_3_with_a_road_at_night_for_game.glb')
report=[];all_points=[]
for obj in bpy.data.objects:
 if obj.type!='MESH':continue
 points=np.array([(obj.matrix_world@vertex.co)[:] for vertex in obj.data.vertices]);all_points.append(points)
 report.append({'name':obj.name,'vertices':len(points),'polygons':len(obj.data.polygons),'low':points.min(0).tolist(),'high':points.max(0).tolist(),'materials':[mat.name if mat else '' for mat in obj.data.materials]})
points=np.concatenate(all_points);low=points.min(0);high=points.max(0)
folder=root/'review/forest';folder.mkdir(exist_ok=True)
(folder/'source-inspection.json').write_text(json.dumps({'low':low.tolist(),'high':high.tolist(),'meshes':report},indent=2))
target=Vector((low+high)/2);size=float(max(high-low))
bpy.ops.object.camera_add(location=target+Vector((size*.65,-size*.95,size*.7)))
camera=bpy.context.object;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=size*1.3
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_shadows=False
scene.world=bpy.data.worlds.new('Forest inspection');scene.world.color=(.15,.18,.2)
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.filepath=str(folder/'downloaded-forest.png')
bpy.ops.render.render(write_still=True)
print('FOREST_SOURCE_INSPECTED',low.tolist(),high.tolist(),len(report),flush=True)
