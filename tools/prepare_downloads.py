import bpy,pathlib,json,re,math
from mathutils import Vector,Matrix
ROOT=pathlib.Path(__file__).resolve().parents[1]
DOWNLOADS=pathlib.Path(r'C:\Users\elles\Downloads')
OUT=ROOT/'game'/'downloaded'
OUT.mkdir(exist_ok=True)
CONFIG={
 'burg_arnstein_harkerode_deutschland.glb':('arnstein_castle',52,110000),
 'castle_of_santa_maria_da_feira.glb':('feira_castle',64,160000),
 'castle_xix.glb':('castle_xix',45,110000),
 'castle_hallway_02.glb':('castle_hallway',12,50000),
 'element_of_a_17th_century_russian_fortress.glb':('fortress',24,100000),
 'viking_town_hall.glb':('viking_hall',18,60000),
 'viking_house.glb':('viking_house',12,50000),
 'medieval_viking_house.glb':('medieval_house',16,90000),
 'vikingnaust_-_veya.glb':('boathouse',20,70000),
 'lowpoly_mideval_tower.glb':('watchtower',12,40000),
 'medieval_forge.glb':('downloaded_forge',10,50000),
 'medieval_warrior.glb':('warrior_display',2.0,60000),
 'medieval_crossbow.glb':('crossbow',1.0,30000),
 'cat_in_motion_3d_model_free.glb':('resting_cat',0.55,35000),
 'ultimate_animal_pack_100_animals__50_off.glb':('wildlife_collection',50,140000),
 'village.glb':('satellite_village',85,180000),
 'psx_grave_pack.glb':('grave_display',3,10000),
 'free_medieval_paintings_pack.glb':('paintings',1.1,20000),
 'lowpoly_village_tools_set.glb':('tools',1.0,20000),
 'get_out_-_asset_set.glb':('trade_items',1.0,30000)
}
manifest=[]
def world_meshes(objects):
 for obj in objects:
  transform=obj.matrix_world.copy()
  obj.parent=None
  obj.data=obj.data.copy()
  obj.data.transform(transform)
  obj.matrix_world=Matrix.Identity(4)
def bounds(objects):
 points=[p.co for obj in objects for p in obj.data.vertices]
 low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
 high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 return low,high
def normalize(objects,size,vertical=False):
 low,high=bounds(objects)
 scale=size/max((high-low).z if vertical else max((high-low).x,(high-low).y),0.001)
 centre=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
 for obj in objects:
  for v in obj.data.vertices:v.co=(v.co-centre)*scale
 return [round(x,3) for x in (high-low)*scale]
def export(objects,path):
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 path.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_materials='EXPORT')
for filename,(key,size,budget) in CONFIG.items():
 path=DOWNLOADS/filename
 if not path.exists():continue
 cache=OUT/(key+'-manifest.json')
 if cache.exists():
  manifest.append(json.loads(cache.read_text()));continue
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(path))
 objects=[o for o in bpy.data.objects if o.type=='MESH' and not (o.name.startswith('50_') or '-50%' in o.name)]
 world_meshes(objects)
 for image in bpy.data.images:
  if image.type!='IMAGE' or not image.has_data:continue
  w,h=image.size
  if max(w,h)>1024:
   ratio=1024/max(w,h);image.scale(max(1,int(w*ratio)),max(1,int(h*ratio)))
 total=sum(sum(max(0,len(p.vertices)-2) for p in o.data.polygons) for o in objects)
 ratio=min(1,budget/max(total,1))
 for obj in objects:
  if len(obj.data.polygons)>1000 and ratio<0.95:
   bpy.context.view_layer.objects.active=obj
   obj.select_set(True)
   modifier=obj.modifiers.new('Runtime mesh reduction','DECIMATE');modifier.ratio=ratio
   bpy.ops.object.modifier_apply(modifier=modifier.name)
 record={'source':str(path),'id':key,'original_triangles':total,'parts':[]}
 if key in ['paintings','tools','trade_items']:
  for i,obj in enumerate(objects):
   if key=='paintings':
    low,high=bounds([obj]);thin=min(range(3),key=lambda i:(high-low)[i])
    rotation=Matrix.Rotation(math.pi/2,4,'X') if thin==2 else Matrix.Rotation(math.pi/2,4,'Z') if thin==0 else Matrix.Identity(4)
    obj.data.transform(rotation)
   dimensions=normalize([obj],size,vertical=key=='paintings')
   part=f'{key}/{i:02d}.glb';export([obj],OUT/part)
   record['parts'].append({'file':part,'name':obj.name,'dimensions':dimensions,'future_trade_item':key in ['tools','trade_items']})
 else:
  dimensions=normalize(objects,size,vertical=key in ['warrior_display','resting_cat','watchtower'])
  export(objects,OUT/(key+'.glb'))
  record['file']=key+'.glb';record['dimensions']=dimensions
 cache.write_text(json.dumps(record,indent=2))
 manifest.append(record)
 print('PREPARED_DOWNLOAD',key,'source_triangles',total,'dimensions',record.get('dimensions'),'parts',len(record['parts']),flush=True)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('DOWNLOADS_PREPARED',len(manifest),flush=True)
