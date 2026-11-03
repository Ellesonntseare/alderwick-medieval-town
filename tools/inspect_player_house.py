import bpy,json,pathlib,numpy as np,sys,bmesh
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1]
interior='--interior' in sys.argv
folder='player-home-interior' if interior else 'player-home'
source=pathlib.Path(r'C:\Users\elles\Downloads')/('the_interior_14_is_spacious.glb' if interior else 'mitterkirchen_-_topferwerkstatt_potters_house.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
rows=[];all_points=[]
for obj in meshes:
 points=np.array([(obj.matrix_world@v.co)[:] for v in obj.data.vertices]);all_points.append(points)
 rows.append(dict(name=obj.name,vertices=len(points),low=points.min(0).tolist(),high=points.max(0).tolist()))
points=np.concatenate(all_points);low=points.min(0);high=points.max(0);centre=(low+high)/2;span=max(high-low)
(root/'review'/folder).mkdir(parents=True,exist_ok=True)
(root/'review'/folder/'source-inspection.json').write_text(json.dumps({'meshes':rows,'low':low.tolist(),'high':high.tolist()},indent=2))
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_cavity=True
scene.world=bpy.data.worlds.new('Review');scene.world.color=(.16,.19,.22)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam
scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
for name,direction in [('front',(1,-1,.65)),('back',(-1,1,.65)),('top',(0,0,1))]:
 cam.location=Vector(centre)+Vector(direction).normalized()*span*1.8
 cam.rotation_euler=(Vector(centre)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=span*1.2
 scene.render.filepath=str(root/('review/'+folder+'/'+name+'.png'));bpy.ops.render.render(write_still=True)
if interior:
 for obj in meshes:
  bm=bmesh.new();bm.from_mesh(obj.data)
  above=[v for v in bm.verts if (obj.matrix_world@v.co).z>low[2]+(high[2]-low[2])*.55]
  bmesh.ops.delete(bm,geom=above,context='VERTS');bm.to_mesh(obj.data);bm.free()
 cam.location=Vector(centre)+Vector((1,-1,1)).normalized()*span*1.8
 cam.rotation_euler=(Vector(centre)-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(root/('review/'+folder+'/cutaway.png'));bpy.ops.render.render(write_still=True)
print('PLAYER_HOUSE_INSPECTED',json.dumps(rows),flush=True)
