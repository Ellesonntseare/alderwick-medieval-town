import bpy
import pathlib
from mathutils import Vector

root = pathlib.Path(__file__).resolve().parents[1]
out = root / "review" / "characters"
out.mkdir(parents=True, exist_ok=True)
groups = [
    [("saxon", "Gareth", "Western gate guard"), ("bruce", "Duncan", "Supply courier"), ("armoured_assassin", "Selene", "Night watch")],
    [("robed_scholar", "Ivor", "Archivist"), ("medieval_woman", "Roslin", "Herbalist"), ("cult_archer", "Fenn", "Range keeper")],
]
for number, group in enumerate(groups, 1):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for index, (style, name, role) in enumerate(group):
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(root/'game/characters'/(style+'.glb')))
        imported=[obj for obj in bpy.data.objects if obj not in before]
        for obj in imported:
            if obj.name.startswith('Icosphere'):
                obj.hide_render=True
            if obj.parent is None:obj.location.x+=index*2.35
        bpy.ops.object.text_add(location=(index*2.35, -0.8, 0.03))
        text = bpy.context.object
        text.rotation_euler = (1.57079632679, 0, 0)
        text.data.body = name + "\n" + role
        text.data.align_x = 'CENTER'
        text.data.size = 0.13
        text.data.space_line = 1.3
    scene.frame_set(0)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.025))
    floor = bpy.context.object
    material = bpy.data.materials.new("Preview ground")
    material.diffuse_color=(0.19,0.22,0.24,1)
    floor.data.materials.append(material)
    bpy.ops.object.camera_add(location=(2.35, -10, 2.45))
    camera = bpy.context.object
    camera.rotation_euler=(Vector((2.35,0,0.80))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=7.2
    scene.camera=camera
    scene.render.engine='BLENDER_WORKBENCH'
    scene.display.shading.light='STUDIO'
    scene.display.shading.color_type='TEXTURE'
    scene.display.shading.show_shadows=False
    scene.display.shading.show_cavity=True
    scene.display.shading.background_type='WORLD'
    scene.world=bpy.data.worlds.new('Preview backdrop')
    scene.world.color=(0.12,0.15,0.18)
    scene.view_settings.view_transform='Standard'
    scene.render.resolution_x=1800
    scene.render.resolution_y=1050
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(out / f"new-residents-{number}.png")
    bpy.ops.render.render(write_still=True)
    print("RESIDENT_PREVIEW_RENDERED",number,flush=True)
