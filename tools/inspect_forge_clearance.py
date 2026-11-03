import bpy
import pathlib
from mathutils import Vector

root = pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / 'game/downloaded/downloaded_forge.glb'))
scene = bpy.context.scene
deps = bpy.context.evaluated_depsgraph_get()
for y in [0.8, 0.6, 0.4, 0.2, 0, -0.3, -0.6, -0.9, -1.3, -1.6]:
    for x in [1.0, 1.25, 1.5]:
        hit, point, normal, index, obj, matrix = scene.ray_cast(deps, Vector((x, y, 1.4)), Vector((0, 0, -1)), distance=2.5)
        print('FORGE_FLOOR', x, y, round(point.z, 4) if hit else None, obj.name if hit else '', flush=True)
for z in [0.6, 0.8, 1.0, 1.2]:
    hit, point, normal, index, obj, matrix = scene.ray_cast(deps, Vector((1.25, 1.75, z)), Vector((0, -1, 0)), distance=4)
    print('FORGE_ENTRY_RAY', z, list(point) if hit else None, obj.name if hit else '', flush=True)
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='TEXTURE'
scene.world=bpy.data.worlds.new('Review')
scene.world.color=(.15,.17,.2)
bpy.ops.object.camera_add()
cam=bpy.context.object
scene.camera=cam
scene.render.resolution_x=1000
scene.render.resolution_y=800
scene.render.resolution_percentage=100
cam.location=(1.3,3.5,1.6)
cam.rotation_euler=(Vector((1.3,-0.9,.7))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.lens=28
scene.render.filepath=str(root/'forge-original-entry.png')
bpy.ops.render.render(write_still=True)
