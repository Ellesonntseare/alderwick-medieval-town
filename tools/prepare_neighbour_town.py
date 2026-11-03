"""Preserve the supplied industrial layout at a human doorway scale."""
import bpy,bmesh,pathlib,json,numpy as np
from mathutils import Vector,Matrix
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'game/downloaded/neighbour_town';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'C:\Users\elles\Desktop\chicken_shoot_gun_-_industrial_map.glb')
scale=.85;base=-11.5;doors=[];adjustments=[]
# The separate hideout house is authored in a larger unit scale than the
# warehouses. Fit the whole assembly, including its door and furniture.
house=bpy.data.objects.get('House')
house_meshes=set(obj for obj in house.children_recursive if obj.type=='MESH') if house else set()
house_points=[obj.matrix_world@vertex.co for obj in house_meshes for vertex in obj.data.vertices]
house_low=Vector(tuple(min(p[k] for p in house_points) for k in range(3)))
house_high=Vector(tuple(max(p[k] for p in house_points) for k in range(3)))
house_pivot=(house_low+house_high)/2
house_pivot.z=-4.703463554382324
house_factor=2.244/(7.436761856079102*scale)
adjustments.append({'name':'Complete hideout house assembly','human_door_height_m':2.244,'assembly_scale':house_factor})
for obj in list(bpy.data.objects):
 if obj.type!='MESH':continue
 world=obj.matrix_world.copy();obj.parent=None;obj.data.transform(world);obj.matrix_world=Matrix.Identity(4)
 if obj in house_meshes:
  for vertex in obj.data.vertices:
   vertex.co=house_pivot+(vertex.co-house_pivot)*house_factor
   vertex.co.z+=base-house_pivot.z
 points=np.array([v.co[:] for v in obj.data.vertices]);lo=points.min(0);hi=points.max(0);mid=(lo+hi)/2
 # This source includes a few props with different unit scales.
 target=.82 if 'table_2_model' in obj.name.lower() else 1.0 if 'barrel_1_' in obj.name.lower() and hi[2]-lo[2]>2 else None
 factor=target/((hi[2]-lo[2])*scale) if target else 1
 pivot=Vector((mid[0],mid[1],lo[2]))
 if factor!=1:
  for vertex in obj.data.vertices:vertex.co=pivot+(vertex.co-pivot)*factor
  adjustments.append({'name':obj.name,'height_m':target})
 # Create a real eight-metre opening in the original north boundary fence.
 if 'fence' in obj.name.lower() and lo[1]>172 and lo[0]<5 and hi[0]>-5:
  bm=bmesh.new();bm.from_mesh(obj.data)
  for x in [-5,5]:bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=Vector((x,0,0)),plane_no=Vector((1,0,0)),dist=.0001)
  bmesh.ops.delete(bm,geom=[face for face in bm.faces if abs(face.calc_center_median().x)<4.999],context='FACES')
  bm.to_mesh(obj.data);bm.free()
 for vertex in obj.data.vertices:vertex.co=Vector((vertex.co.x*scale,vertex.co.y*scale,(vertex.co.z-base)*scale+.03))
 if 'door' in obj.name.lower():
  p=np.array([v.co[:] for v in obj.data.vertices]);a=p.min(0);b=p.max(0)
  if b[2]-a[2]>=1.85:
   doors.append({'name':obj.name,'height':float(b[2]-a[2]),'width':float(max(b[0]-a[0],b[1]-a[1]))})
for obj in list(bpy.data.objects):
 if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True)
# Chunk static geometry for culling, leaving real door meshes separate.
groups={}
door_names={entry['name'] for entry in doors}
for obj in list(bpy.data.objects):
 if obj.name in door_names:continue
 points=[v.co for v in obj.data.vertices]
 if not points:continue
 centre=sum(points,Vector())/len(points)
 key=(int(centre.x//32),int(centre.y//32),tuple(mat.name if mat else '' for mat in obj.data.materials))
 groups.setdefault(key,[]).append(obj)
for index,items in enumerate(groups.values()):
 bpy.ops.object.select_all(action='DESELECT')
 for obj in items:obj.select_set(True)
 bpy.context.view_layer.objects.active=items[0]
 if len(items)>1:bpy.ops.object.join()
 bpy.context.object.name='DistrictChunk_'+str(index)
for image in bpy.data.images:
 if max(image.size)>1024:
  factor=1024/max(image.size);image.scale(max(1,round(image.size[0]*factor)),max(1,round(image.size[1]*factor)))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'industrial_town.glb'),export_format='GLB',use_selection=True,export_animations=False)
(out/'layout.json').write_text(json.dumps({'scale':scale,'ground_source_height':base,'reference_human_door_height':2.64*scale,'width':446*scale,'depth':397.9*scale,'position':[0,0,410],'entry':[0,.03,410-174*scale],'doors':doors,'prop_adjustments':adjustments,'static_chunks':len(groups)},indent=2))
assert all(1.85<=door['height']<=2.7 for door in doors),doors
print('NEIGHBOUR_TOWN_PREPARED scale=',scale,'human_door=',2.64*scale,'doors=',len(doors),'chunks=',len(groups),flush=True)
