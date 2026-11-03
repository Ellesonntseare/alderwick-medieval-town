import bpy,pathlib,json
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
results={}
for key,file,ys,xs in [('fere','chateau_de_fere_en_tardenois_02.glb',[14.5,15,15.5,16],[-10,-8,-6,-4,-2,0,2,4,6]),('montfaucon','chateau_de_montfaucon_25.glb',[12,12.5,13,13.5,14,14.5],[-11,-9,-7,-5,-3,-1,1,3,5,7])]:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(pathlib.Path(r'C:\Users\elles\Downloads')/file));deps=bpy.context.evaluated_depsgraph_get();rows=[]
 for y in ys:
  row=[]
  for x in xs:
   hit,p,n,face,obj,matrix=bpy.context.scene.ray_cast(deps,Vector((x,y,100)),Vector((0,0,-1)))
   row.append(round(p.z,3) if hit else None)
  rows.append({'y':y,'x':xs,'z':row})
 results[key]=rows
(ROOT/'chateau-ground-samples.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results),flush=True)
