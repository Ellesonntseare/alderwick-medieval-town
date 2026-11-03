import bpy,bmesh,pathlib,math,json,numpy as np
from mathutils import Vector,Matrix,Quaternion
R=pathlib.Path(__file__).resolve().parents[1]
changes=[]
def rigid(obj,indices,bone):
 for group in obj.vertex_groups:group.remove(indices)
 group=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
 group.add(indices,1,'REPLACE')
def components(obj):
 bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table();bm.verts.index_update()
 unseen=set(bm.verts);result=[]
 while unseen:
  first=unseen.pop();group={first};stack=[first]
  while stack:
   for edge in stack.pop().link_edges:
    other=edge.other_vert(first) if first in edge.verts else None
    for other in edge.verts:
     if other in unseen:unseen.remove(other);group.add(other);stack.append(other)
  result.append([v.index for v in group])
 bm.free();return result
for style in ['saxon','bruce','robed_scholar','medieval_woman']:
 bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/rigged-characters'/(style+'.blend')))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 meshes=[o for o in bpy.data.objects if o.type=='MESH']
 if style=='saxon':
  swords=[o for o in meshes if o.name.startswith('Sword_07')]
  # Mount the complete sword alongside its existing hip scabbard, with
  # the blade pointing down. All parts receive the same rigid transform.
  pivot=Vector((-.77,0,1.44));turn=Matrix.Rotation(math.pi/2,4,'X')
  destination=Vector((.29,-.035,1.12))
  for obj in swords:
   for vertex in obj.data.vertices:vertex.co=turn.to_3x3()@(vertex.co-pivot)+destination
   rigid(obj,list(range(len(obj.data.vertices))),'Hips')
  shields=[o for o in meshes if o.name.startswith('Shield_13')]
  # Keep the shield together at the forearm rather than leaving one half
  # at the original T-pose wrist.
  for obj in shields:rigid(obj,list(range(len(obj.data.vertices))),'LowerArm.L')
  changes.append('Gareth: complete sword rotated down and attached at hip')
 if style=='bruce':
  bpy.context.view_layer.objects.active=rig
  bpy.ops.object.mode_set(mode='EDIT')
  for bone in rig.data.edit_bones:
   if bone.name.startswith(('Shoulder.','UpperArm.','LowerArm.','Wrist.')):
    shift=Vector((.065 if bone.name.endswith('.L') else -.065,0,0));bone.head+=shift;bone.tail+=shift
  bpy.ops.object.mode_set(mode='OBJECT')
  for obj in meshes:
   for side,sign in [('L',1),('R',-1)]:
    hand=[v.index for v in obj.data.vertices if v.co.x*sign>.70 and v.co.z>1.25]
    if hand:rigid(obj,hand,'Wrist.'+side)
    for low,high,bone in [(.25,.48,'UpperArm.'),(.48,.70,'LowerArm.')]:
     ids=[v.index for v in obj.data.vertices if low<v.co.x*sign<=high and v.co.z>1.25]
     if ids:rigid(obj,ids,bone+side)
  changes.append('Duncan: separated shoulders and confined limb weights to arm bones')
 if style in ['robed_scholar','medieval_woman']:
  for obj in meshes:
   for part in components(obj):
    coords=[obj.data.vertices[i].co for i in part]
    lo=Vector(tuple(min(p[k] for p in coords) for k in range(3)))
    hi=Vector(tuple(max(p[k] for p in coords) for k in range(3)))
    centre=(lo+hi)*.5
    if hi.z<.32 and len(part)>8:
     rigid(obj,part,'Foot.'+('L' if centre.x>0 else 'R'))
    elif .70<centre.z<1.3 and abs(centre.x)>.12 and (hi-lo).z<.35 and (hi-lo).x<.25:
     rigid(obj,part,'Wrist.'+('L' if centre.x>0 else 'R'))
   # Hands are distinct from the lower robe even when the import joins
   # several disconnected pieces under one mesh/material.
   material=' '.join(m.name for m in obj.data.materials if m)
   skin=(style=='robed_scholar' and material=='Head') or (style=='medieval_woman' and obj.name.startswith('Object_6'))
   if skin:
    for side,sign in [('L',1),('R',-1)]:
     ids=[v.index for v in obj.data.vertices if v.co.z<1.25 and v.co.x*sign>.13]
     if ids:rigid(obj,ids,'Wrist.'+side)
  changes.append(style+': hands separated from robe weights; boots follow feet')
 bpy.context.scene.frame_set(0)
 bpy.ops.wm.save_as_mainfile(filepath=str(R/'source-assets/rigged-characters'/(style+'.blend')))
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(R/'game/characters'/(style+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True)
 print('CORRECTED_ADULT',style,flush=True)
for style in ['runner_child','runner_youth']:
 folder=R/'source-assets/medieval-runner-previews'
 bpy.ops.wm.open_mainfile(filepath=str(folder/(style+'.blend')))
 if style=='runner_youth':
  head=[o for o in bpy.data.objects if o.type=='MESH' and not o.name.startswith('Male_')]
  for obj in head:
   for vertex in obj.data.vertices:vertex.co=Vector((0,0,1.28))+(vertex.co-Vector((0,0,1.28)))*.80
  changes.append('Older runner: head reduced 20 percent, neck position preserved')
 else:
  body=next(o for o in bpy.data.objects if o.name.startswith('Boy01_Body_Geo'))
  # A dedicated warm skin material replaces the pale face region only;
  # eyes, brows, hair, glasses and the green headwear retain their textures.
  mat=bpy.data.materials.new('Runner child warm skin')
  mat.diffuse_color=(.58,.32,.19,1)
  mat.use_nodes=True
  shader=mat.node_tree.nodes.get('Principled BSDF')
  shader.inputs['Base Color'].default_value=(.58,.32,.19,1)
  shader.inputs['Roughness'].default_value=.85
  index=len(body.data.materials);body.data.materials.append(mat)
  for polygon in body.data.polygons:
   centre=polygon.center
   if centre.y<-.025 and centre.z<1.235 and centre.z>1.015:polygon.material_index=index
  changes.append('Small runner: warm face material, preserving eye and accessory textures')
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/(style+'.blend')))
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(folder/(style+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
(R/'review/characters/corrections-applied.json').write_text(json.dumps(changes,indent=2))
print('PREVIEW_CORRECTIONS_COMPLETE',flush=True)
