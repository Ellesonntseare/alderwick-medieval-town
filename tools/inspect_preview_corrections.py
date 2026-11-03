import bpy,pathlib,json
from mathutils import Vector
R=pathlib.Path(__file__).resolve().parents[1]
report={}
for style in ['saxon','bruce','robed_scholar','medieval_woman']:
 bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/rigged-characters'/(style+'.blend')))
 objects=[]
 for obj in bpy.data.objects:
  if obj.type!='MESH':continue
  pts=[obj.matrix_world@v.co for v in obj.data.vertices]
  lo=[min(p[k] for p in pts) for k in range(3)];hi=[max(p[k] for p in pts) for k in range(3)]
  objects.append({'name':obj.name,'low':lo,'high':hi,'materials':[m.name if m else '' for m in obj.data.materials]})
 report[style]=objects
bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/medieval-runner-previews/runner_child.blend'))
report['child']=[{'name':o.name,'materials':[{'name':m.name,'diffuse':list(m.diffuse_color),'images':[(n.name,n.image.name if n.image else '',n.image.colorspace_settings.name if n.image else '') for n in m.node_tree.nodes if n.type=='TEX_IMAGE']} for m in o.data.materials if m]} for o in bpy.data.objects if o.type=='MESH' and not o.name.startswith('Male_')]
(R/'review/characters/correction-inspection.json').write_text(json.dumps(report,indent=2))
print('CORRECTION_INSPECTION_READY',flush=True)
