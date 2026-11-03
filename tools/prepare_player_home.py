import bpy,pathlib,json,bmesh
from mathutils import Vector,Matrix
root=pathlib.Path(__file__).resolve().parents[1]
dest=root/'game/downloaded/player-home';dest.mkdir(parents=True,exist_ok=True)
for name,filename,offset in [('exterior','mitterkirchen_-_topferwerkstatt_potters_house.glb',Vector((-.31,-7.58,-15.0))),('interior','the_interior_14_is_spacious.glb',Vector((0,0,0)))]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(pathlib.Path(r'C:\Users\elles\Downloads')/filename))
 for obj in list(bpy.data.objects):
  if obj.type!='MESH':continue
  # Large surrounding spheres are source presentation helpers, outside the room.
  if name=='interior' and obj.name.startswith('Sphere'):
   bpy.data.objects.remove(obj,do_unlink=True);continue
  obj.data.transform(Matrix.Translation(-offset)@obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
  if name=='interior':
   bm=bmesh.new();bm.from_mesh(obj.data)
   for co,no in [((6.1,0,0),(1,0,0)),((0,-.1,0),(0,1,0)),((0,-4.9,0),(0,1,0))]:
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=co,plane_no=no,dist=.0001)
   remove=[f for f in bm.faces if f.calc_center_median().x>6.1 and -4.9<f.calc_center_median().y<-.1 and 2.2<f.calc_center_median().z<3.2]
   bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(obj.data);bm.free()
 for image in bpy.data.images:
  if max(image.size)>2048:
   ratio=2048/max(image.size);image.scale(max(1,int(image.size[0]*ratio)),max(1,int(image.size[1]*ratio)))
 bpy.ops.export_scene.gltf(filepath=str(dest/(name+'.glb')),export_format='GLB',export_yup=True,export_animations=False)
 print('PLAYER_HOME_EXPORTED',name,flush=True)
(dest/'credits.json').write_text(json.dumps({'exterior':{'title':"Mitterkirchen - Töpferwerkstatt (potter's house)",'author':'Mario_Wallner','license':'CC-BY-NC-4.0','source':'https://sketchfab.com/3d-models/mitterkirchen-topferwerkstatt-potters-house-dfbeb7d8c21141bea3fc041d86705884'},'interior':{'title':'The interior (14) is spacious.','author':'dasy444','license':'SKETCHFAB Standard','source':'https://sketchfab.com/3d-models/the-interior-14-is-spacious-79262bfc39d54fd2a0edc9d80fafdb6d'},'changes':'Transforms baked; exterior grounded; interior presentation spheres omitted; textures capped at2048. Original downloads preserved.'},indent=2))
