import bpy,json,pathlib
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parents[1]
records=[]
for filename in ['cow_idle.glb','horse_basemesh.glb','sheep.glb','sheep-test_non-commercial.glb']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(root/'source-assets/new-wildlife'/filename))
 row={'file':filename,'armatures':[],'meshes':[]}
 for obj in bpy.data.objects:
  if obj.type=='ARMATURE':
   row['armatures'].append({'name':obj.name,'bones':[dict(name=b.name,head=list(obj.matrix_world@b.head_local),tail=list(obj.matrix_world@b.tail_local),parent=b.parent.name if b.parent else '') for b in obj.data.bones]})
  if obj.type=='MESH':
   points=[obj.matrix_world@v.co for v in obj.data.vertices]
   row['meshes'].append(dict(name=obj.name,vertices=len(points),low=[min(p[k] for p in points) for k in range(3)],high=[max(p[k] for p in points) for k in range(3)],groups=[g.name for g in obj.vertex_groups]))
 records.append(row)
(root/'animal-rig-inspection.json').write_text(json.dumps(records,indent=2))
print('ANIMAL_RIG_INSPECTION_COMPLETE')
