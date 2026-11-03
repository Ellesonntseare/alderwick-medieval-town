import bpy,pathlib
from mathutils import Vector
R=pathlib.Path(__file__).resolve().parents[1]
exec(compile((R/'tools/render_new_residents.py').read_text(),str(R/'tools/render_new_residents.py'),'exec'))
bpy.ops.wm.read_factory_settings(use_empty=True)
for index,style in enumerate(['runner_child','runner_youth']):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(R/'source-assets/medieval-runner-previews'/(style+'.glb')))
 for obj in bpy.data.objects:
  if obj not in before and obj.parent is None:obj.location.x+=index*1.6
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_shadows=False
scene.display.shading.show_cavity=True
scene.world=bpy.data.worlds.new('Corrected runner preview')
scene.world.color=(.14,.17,.20)
bpy.ops.object.camera_add(location=(.8,-8,1.65))
camera=bpy.context.object
camera.rotation_euler=(Vector((.8,0,.79))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=3.8;scene.camera=camera
scene.render.resolution_x=1800;scene.render.resolution_y=1150;scene.render.resolution_percentage=100
scene.render.filepath=str(R/'review/characters/runner-corrected-preview.png')
bpy.ops.render.render(write_still=True)
print('CORRECTED_REVIEW_RENDERED',flush=True)
