import bpy,json,pathlib
p=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town')
bpy.ops.wm.open_mainfile(filepath=str(p/'source-assets'/'all-together'/'All together'/'Blends'/'All together.blend'))
data={
 'objects':[{'name':o.name,'type':o.type,'dimensions':list(o.dimensions),'location':list(o.location),'armature':o.parent.name if o.parent else None} for o in bpy.data.objects],
 'actions':[{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions],
 'collections':[c.name for c in bpy.data.collections],
 'armatures':[{'name':a.name,'bones':len(a.bones)} for a in bpy.data.armatures]
}
(p/'character-inventory.json').write_text(json.dumps(data,indent=2))
print(json.dumps({'collections':data['collections'],'armatures':data['armatures'],'actions':data['actions'],'meshes':[x['name'] for x in data['objects'] if x['type']=='MESH']},indent=2))
