"""Prepare the two actual scanned districts, preserving source downloads."""
import bpy,bmesh,json,pathlib,shutil
from mathutils import Vector,Matrix

ROOT=pathlib.Path(__file__).resolve().parents[1]
DOWNLOADS=pathlib.Path(r'C:\Users\elles\Downloads')
OUT=ROOT/'game/downloaded/chateaux'
SOURCE=ROOT/'source-assets/chateaux'
OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
SPECS=[
 dict(id='fere_chateau',title='Fère-en-Tardenois',file='chateau_de_fere_en_tardenois_02.glb',scale=5.0,entry=[-8.0,15.0,.921],inside=[3.0,15.0,1.07],position=[245,0,70]),
 dict(id='montfaucon_chateau',title='Montfaucon',file='chateau_de_montfaucon_25.glb',scale=4.0,entry=[-9.0,14.5,-.427],inside=[-2.0,14.5,.02],position=[265,0,-90])
]
records=[]
for spec in SPECS:
 shutil.copy2(DOWNLOADS/spec['file'],SOURCE/spec['file'])
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(DOWNLOADS/spec['file']))
 objects=[o for o in bpy.data.objects if o.type=='MESH']
 for obj in objects:
  transform=obj.matrix_world.copy();obj.parent=None;obj.data=obj.data.copy();obj.data.transform(transform);obj.matrix_world=Matrix.Identity(4)
 points=[v.co.copy() for obj in objects for v in obj.data.vertices]
 low=Vector([min(p[k] for p in points) for k in range(3)]);high=Vector([max(p[k] for p in points) for k in range(3)])
 centre=Vector(((low.x+high.x)/2,(low.y+high.y)/2,0))
 scale=spec['scale'];entry=Vector(spec['entry']);ground=entry.z
 removed=0
 for obj in objects:
  # A short adult-sized passage joins the outside to the real existing
  # entrance. It does not replace the castle courtyard with a separate room.
  bm=bmesh.new();bm.from_mesh(obj.data)
  inside=Vector(spec['inside']);slope=(inside.z-ground)/(inside.x-entry.x)
  bounds=[low.x-1,inside.x+.3,entry.y-1.2/scale,entry.y+1.2/scale,ground-.025,ground+2.6/scale]
  for axis,value in [(0,bounds[0]),(0,bounds[1]),(1,bounds[2]),(1,bounds[3])]:
   co=Vector((0,0,0));co[axis]=value;normal=Vector((0,0,0));normal[axis]=1
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=co,plane_no=normal,clear_inner=False,clear_outer=False)
  for height in bounds[4:]:
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=Vector((entry.x,0,height)),plane_no=Vector((-slope,0,1)).normalized(),clear_inner=False,clear_outer=False)
  a,b,c,d,e,f=bounds
  drop=[face for face in bm.faces if a<face.calc_center_median().x<b and c<face.calc_center_median().y<d and e<face.calc_center_median().z-slope*(face.calc_center_median().x-entry.x)<f]
  removed+=len(drop)
  if drop:bmesh.ops.delete(bm,geom=drop,context='FACES')
  bm.to_mesh(obj.data);bm.free()
  for vertex in obj.data.vertices:
   point=vertex.co
   border=min(point.x-low.x,high.x-point.x,point.y-low.y,high.y-point.y)*scale
   blend=max(0,min(1,border/4.0));blend=blend*blend*(3-2*blend)
   point.x=(point.x-centre.x)*scale
   point.y=(point.y-centre.y)*scale
   point.z=(point.z-ground)*scale*blend-.05*(1-blend)
  obj.data.update()
  # Blending the scanned rim changes its vertical profile. Clear the final
  # outside approach after that blend so foliage cannot close the entrance.
  outer=[(low.x-centre.x)*scale-.5,(entry.x-centre.x)*scale+.1,(entry.y-centre.y)*scale-1.2,(entry.y-centre.y)*scale+1.2,-.03,2.6]
  bm=bmesh.new();bm.from_mesh(obj.data)
  for axis,value in [(0,outer[0]),(0,outer[1]),(1,outer[2]),(1,outer[3]),(2,outer[4]),(2,outer[5])]:
   co=Vector((0,0,0));co[axis]=value;normal=Vector((0,0,0));normal[axis]=1
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=co,plane_no=normal,clear_inner=False,clear_outer=False)
  a,b,c,d,e,f=outer
  drop=[face for face in bm.faces if a<face.calc_center_median().x<b and c<face.calc_center_median().y<d and e<face.calc_center_median().z<f]
  if drop:bmesh.ops.delete(bm,geom=drop,context='FACES')
  bm.to_mesh(obj.data);bm.free()
  for material in obj.data.materials:
   if material:material.use_backface_culling=False
  bpy.context.view_layer.objects.active=obj
  obj.select_set(True)
  faces=len(obj.data.polygons)
  if faces>45000:
   modifier=obj.modifiers.new('District detail budget','DECIMATE');modifier.ratio=min(1,45000/faces)
   bpy.ops.object.modifier_apply(modifier=modifier.name)
  obj.select_set(False)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(spec['id']+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_materials='EXPORT')
 visual_faces=sum(len(obj.data.polygons) for obj in objects)
 for obj in objects:
  bpy.context.view_layer.objects.active=obj
  if len(obj.data.polygons)>16000:
   modifier=obj.modifiers.new('Walkable collision budget','DECIMATE');modifier.ratio=16000/len(obj.data.polygons)
   bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(spec['id']+'_collision.glb')),export_format='GLB',use_selection=True,export_animations=False,export_materials='NONE')
 def runtime(point):
  p=Vector(point)
  return [(p.x-centre.x)*scale,(p.z-ground)*scale,-(p.y-centre.y)*scale]
 record=dict(spec)
 record.update(size=[(high.x-low.x)*scale,(high.z-low.z)*scale,(high.y-low.y)*scale],entry_local=runtime(spec['entry']),inside_local=runtime(spec['inside']),removed_access_faces=removed,visual_faces=visual_faces,collision_faces=sum(len(obj.data.polygons) for obj in objects),terrain_min_y=(low.z-ground)*scale,source_centre=list(centre))
 records.append(record)
 print('CHATEAU_PREPARED',json.dumps(record),flush=True)
(OUT/'layout.json').write_text(json.dumps(records,indent=2))
print('CHATEAUX_PREPARED',len(records),flush=True)
