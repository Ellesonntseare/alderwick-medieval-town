import bpy,pathlib,json
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'game'/'animals'
OUT.mkdir(exist_ok=True)
manifest={}
for species in ['Cow','Horse','Pig','Pug','Sheep']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source-assets'/'farm-animals'/'Blends'/(species+'.blend')))
 if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 objects=[o for o in bpy.data.objects if o.type in ('ARMATURE','MESH')]
 print(species,'objects',[(o.name,o.type,list(o.dimensions),[(m.name,m.type) for m in o.modifiers]) for o in objects],flush=True)
 print('ACTIONS',[(a.name,list(a.frame_range)) for a in bpy.data.actions],flush=True)
 for mat in bpy.data.materials:
  color=tuple(mat.diffuse_color)
  mat.use_nodes=True
  mat.node_tree.nodes.clear()
  output=mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
  shader=mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
  shader.inputs['Base Color'].default_value=color
  shader.inputs['Roughness'].default_value=0.85
  mat.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface'])
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:
  obj.hide_set(False);obj.hide_viewport=False;obj.hide_render=False;obj.hide_select=False
  obj.select_set(True)
  if obj.type=='MESH':
   bpy.context.view_layer.objects.active=obj
   for modifier in list(obj.modifiers):
    if modifier.type=='MIRROR':bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.context.view_layer.update()
 rigs=[o for o in objects if o.type=='ARMATURE']
 if rigs:bpy.context.view_layer.objects.active=rigs[0]
 bpy.context.scene.frame_set(0)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(species+'.glb')),export_format='GLB',use_selection=True,use_visible=False,use_renderable=False,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_materials='EXPORT')
 manifest[species]={'actions':[a.name for a in bpy.data.actions],'objects':[o.name for o in objects]}
(ROOT/'animal-manifest.json').write_text(json.dumps(manifest,indent=2))
print('FARM_ANIMALS_EXPORTED',flush=True)
