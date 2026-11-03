import bpy,collections,json
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\elles\Desktop\Builts\Medieval-Town\source-assets\all-together\All together\Blends\All together.blend')
for name in ['Medieval_Head','Medieval_Body','Medieval_Legs','Worker_Head','Witch_Head']:
 o=bpy.data.objects[name];uv=o.data.uv_layers.active
 groups={}
 for face in o.data.polygons:
  key=tuple(round(c,3) for c in uv.data[face.loop_indices[0]].uv)
  item=groups.setdefault(str(key),{'count':0,'centers':[]})
  item['count']+=1
  if len(item['centers'])<4:item['centers'].append([round(c,3) for c in face.center])
 print(name,json.dumps(groups),flush=True)

for o in [bpy.data.objects['Medieval_Head'],bpy.data.objects['Medieval_Body']]:
 print('ATTR',o.name,[(a.name,a.data_type,a.domain) for a in o.data.attributes], 'MAT',[(m.name,m.diffuse_color[:]) for m in o.data.materials], 'UV',[(v.name,len(v.data)) for v in o.data.uv_layers],flush=True)
