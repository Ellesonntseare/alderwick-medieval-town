import bpy,pathlib,json,hashlib
root=pathlib.Path(__file__).resolve().parents[1]
allowed={'Running.fbx','Fast Run.fbx','Jumping Up.fbx','Falling To Roll.fbx','Hip Hop Dancing.fbx','Silly Dancing.fbx','Twist Dance.fbx','Bboy Uprock Start.fbx','Breakdance Freeze Var 2.fbx'}
files=list(pathlib.Path(r'C:\Users\elles\Downloads').glob('*.fbx'))
files += [p for p in pathlib.Path(r'C:\Users\elles\Downloads\runner').rglob('*.fbx') if p.name in allowed]
seen=set();rows=[]
for p in files:
 if p.name in seen:continue
 seen.add(p.name);bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(p))
 arms=[o for o in bpy.data.objects if o.type=='ARMATURE'];meshes=[o for o in bpy.data.objects if o.type=='MESH']
 row={'file':str(p),'armatures':[{'name':o.name,'bones':[b.name for b in o.data.bones]} for o in arms],'actions':[{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions],'meshes':[]}
 for obj in meshes:
  digest=hashlib.sha256()
  for v in obj.data.vertices:digest.update(str(tuple(round(x,5) for x in v.co)).encode())
  row['meshes'].append({'name':obj.name,'vertices':len(obj.data.vertices),'shape_hash':digest.hexdigest(),'materials':[m.name for m in obj.data.materials if m]})
 rows.append(row)
 (root/'review/action-sources.json').write_text(json.dumps(rows,indent=2))
 print('ACTION_SOURCE',json.dumps(row),flush=True)
(root/'review/action-sources.json').write_text(json.dumps(rows,indent=2))
