import bpy,pathlib,json
ROOT=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source-assets'/'all-together'/'All together'/'Blends'/'All together.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
print('RIG',rig.name,'rotation',list(rig.rotation_euler),'scale',list(rig.scale),flush=True)
print('ACTIONS',[(a.name,len(a.slots)) for a in bpy.data.actions],flush=True)
props=bpy.ops.export_scene.gltf.get_rna_type().properties
print('EXPORT_MODES',[(x.identifier,x.name) for x in props['export_animation_mode'].enum_items],flush=True)
print('IMAGES',[(i.name,i.filepath,i.packed_file is not None) for i in bpy.data.images],flush=True)
keep={'Idle','Walk','Interact','Wave','Run'}
for mat in bpy.data.materials:
 color=tuple(mat.diffuse_color)
 mat.use_nodes=True
 mat.node_tree.nodes.clear()
 output=mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
 shader=mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
 shader.inputs['Base Color'].default_value=color
 shader.inputs['Roughness'].default_value=0.85
 mat.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface'])
for action in list(bpy.data.actions):
 if action.name not in keep: bpy.data.actions.remove(action)
out=ROOT/'game'/'characters'
out.mkdir(exist_ok=True)
# glTF skin export keeps the armature but does not automatically bake the
# source meshes' Mirror modifiers. Apply only Mirror, preserving rig weights.
for obj in bpy.data.objects:
 if obj.type!='MESH' or not obj.name.startswith(('Medieval_','Worker_','Witch_','Adventurer_')):continue
 obj.hide_set(False)
 obj.hide_viewport=False
 obj.hide_select=False
 bpy.context.view_layer.objects.active=obj
 obj.select_set(True)
 for modifier in list(obj.modifiers):
  if modifier.type=='MIRROR':
   bpy.ops.object.modifier_apply(modifier=modifier.name)
   print('BAKED_MIRROR',obj.name,len(obj.data.vertices),flush=True)
 for modifier in obj.modifiers:
  assert modifier.type!='MIRROR',obj.name
 # Both sides must exist after baking, including mirrored bone groups.
 xs=[vertex.co.x for vertex in obj.data.vertices]
 assert min(xs)<-0.02 and max(xs)>0.02,(obj.name,min(xs),max(xs))
for style in ['Medieval','Worker','Witch','Adventurer']:
 bpy.ops.object.select_all(action='DESELECT')
 rig.hide_set(False)
 rig.hide_viewport=False
 rig.hide_render=False
 rig.hide_select=False
 rig.select_set(True)
 selected=[]
 for obj in bpy.data.objects:
  if obj.type=='MESH':
   active=obj.name.startswith(style+'_')
   obj.hide_set(not active)
   obj.hide_viewport=not active
   obj.hide_select=False
   obj.hide_render=not active
   if active: obj.select_set(True); selected.append(obj.name)
 bpy.context.view_layer.objects.active=rig
 bpy.context.view_layer.update()
 print('SELECTED',[(o.name,o.type,o.hide_viewport,o.hide_get()) for o in bpy.context.selected_objects],flush=True)
 rig.animation_data_create()
 rig.animation_data.action=bpy.data.actions['Idle']
 bpy.context.scene.frame_set(0)
 bpy.ops.export_scene.gltf(filepath=str(out/(style.lower()+'.glb')),export_format='GLB',use_selection=True,use_visible=False,use_renderable=False,
  export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_materials='EXPORT')
 print('EXPORTED',style,selected,flush=True)
