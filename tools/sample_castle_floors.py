import bpy,pathlib,json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town');result={}
for key,spots in {'arnstein_castle':[(-2,1),(-2,-2),(-2,-4)],'feira_castle':[(-4,4),(-3,0),(8,-5)],'castle_xix':[(0,5),(0,-5),(0,-17)]}.items():
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(R/'game/downloaded'/(key+'.glb')));verts=[];faces=[]
 for o in bpy.data.objects:
  if o.type!='MESH':continue
  offset=len(verts);verts.extend([o.matrix_world@v.co for v in o.data.vertices]);faces.extend([tuple(offset+i for i in p.vertices) for p in o.data.polygons])
 bvh=BVHTree.FromPolygons(verts,faces);samples={}
 for x,y in spots:
  origin=Vector((x,y,30));heights=[]
  for i in range(12):
   point,normal,index,dist=bvh.ray_cast(origin,Vector((0,0,-1)),60)
   if point is None:break
   heights.append([round(point.z,3),round(normal.z,2)]);origin=point-Vector((0,0,.015))
  samples[str((x,y))]=heights
 result[key]=samples;print('CASTLE_FLOOR_SAMPLES',key,samples,flush=True)
(R/'native-castle-floors.json').write_text(json.dumps(result,indent=2))
