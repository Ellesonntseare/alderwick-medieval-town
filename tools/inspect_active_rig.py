import bpy,pathlib,json,numpy as np
root=pathlib.Path(__file__).resolve().parents[1]
out={}
for style in ['bruce','runner_child']:
 bpy.ops.wm.open_mainfile(filepath=str(root/'source-assets/rigged-characters'/(style+'.blend')))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 rig.data.pose_position='REST'
 out[style]=[]
 for obj in bpy.data.objects:
  if obj.type!='MESH':continue
  points=np.array([v.co[:] for v in obj.data.vertices]);lo=points.min(0);hi=points.max(0)
  out[style].append({'name':obj.name,'lo':lo.tolist(),'hi':hi.tolist(),'verts':len(points)})
(root/'review/characters/active-rig-inspection.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out))
