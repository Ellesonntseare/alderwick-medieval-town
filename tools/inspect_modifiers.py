import bpy
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\elles\Desktop\Builts\Medieval-Town\source-assets\all-together\All together\Blends\All together.blend')
for o in bpy.data.objects:
 if o.type=='MESH' and o.name.startswith(('Medieval','Worker','Witch','Adventurer')):
  print(o.name,'vertices',len(o.data.vertices),'modifiers',[(m.name,m.type,m.show_viewport,m.show_render) for m in o.modifiers],flush=True)
  for m in o.modifiers:
   if m.type=='MIRROR':print('MIRROR',list(m.use_axis),m.mirror_object,m.use_clip,flush=True)
