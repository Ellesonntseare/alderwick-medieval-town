import bpy,pathlib
from mathutils import Vector
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town');bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(R/'game/downloaded/downloaded_forge.glb'))
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.world=bpy.data.worlds.new('Review');scene.world.color=(.15,.17,.2);bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
for name,location in [('north',(8,11,6)),('south',(8,-11,6)),('inside',(0,3,1.8))]:
 cam.location=location;cam.rotation_euler=(Vector((0,0,1.1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.lens=32;scene.render.filepath=str(R/('forge-original-'+name+'.png'));bpy.ops.render.render(write_still=True)
