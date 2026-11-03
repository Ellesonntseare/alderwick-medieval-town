import bpy,pathlib,math,numpy as np
from mathutils import Vector,Matrix
R=pathlib.Path(__file__).resolve().parents[1]
for style in ['bruce','robed_scholar','medieval_woman']:
 folder=R/'source-assets/rigged-characters'
 bpy.ops.wm.open_mainfile(filepath=str(folder/(style+'.blend1')))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 if style=='bruce':
  # Keep the original smooth deformation; separate the sleeve/gauntlet
  # silhouette by shifting only source arm vertices, not the bone chain.
  for obj in bpy.data.objects:
   if obj.type!='MESH':continue
   for v in obj.data.vertices:
    if abs(v.co.x)>.23 and v.co.z>1.25:
     v.co.x+=.045*(1 if v.co.x>0 else -1)
 else:
  # These sources already have lowered arms and individually posed hands.
  # Preserve that source arm pose while body/legs retain their motion clips.
  for action in bpy.data.actions:
   for layer in action.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      for curve in bag.fcurves:
       if not any(name in curve.data_path for name in ['Shoulder.','UpperArm.','LowerArm.','Wrist.']):continue
       value=1 if 'rotation_quaternion' in curve.data_path and curve.array_index==0 else 0
       for key in curve.keyframe_points:key.co.y=value;key.handle_left.y=value;key.handle_right.y=value
 bpy.context.scene.frame_set(0)
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/(style+'.blend')))
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(R/'game/characters'/(style+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'source-assets/rigged-characters/saxon.blend'))
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.name.startswith('Shield_13'):
  pivot=Vector((.80,.008,1.44));turn=Matrix.Rotation(-math.pi/2,4,'Z')
  for v in obj.data.vertices:v.co=turn.to_3x3()@(v.co-pivot)+pivot
bpy.ops.wm.save_as_mainfile(filepath=str(R/'source-assets/rigged-characters/saxon.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(R/'game/characters/saxon.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True)
folder=R/'source-assets/medieval-runner-previews'
bpy.ops.wm.open_mainfile(filepath=str(folder/'runner_child.blend'))
for obj in bpy.data.objects:
 if obj.type!='MESH' or obj.name.startswith('Male_') or 'Eyes' in obj.name or 'Brows' in obj.name:continue
 for mat in obj.data.materials:
  if not mat or not mat.use_nodes:continue
  for node in mat.node_tree.nodes:
   if node.type!='TEX_IMAGE' or not node.image or node.image.colorspace_settings.name!='sRGB':continue
   image=node.image.copy();image.name='Corrected warm face '+node.image.name
   pixels=np.array(image.pixels[:],dtype=np.float32).reshape((-1,4))
   neutral=(pixels[:,:3].min(axis=1)>.55)&((pixels[:,:3].max(axis=1)-pixels[:,:3].min(axis=1))<.16)
   intensity=pixels[neutral,:3].mean(axis=1)
   pixels[neutral,:3]=intensity[:,None]*np.array([.75,.49,.32])
   image.pixels.foreach_set(pixels.ravel());image.update();image.pack();node.image=image
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'runner_child.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(folder/'runner_child.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
print('REFINED_CORRECTIONS_COMPLETE',flush=True)
exec(compile((R/'tools/render_corrected_review.py').read_text(),str(R/'tools/render_corrected_review.py'),'exec'))
