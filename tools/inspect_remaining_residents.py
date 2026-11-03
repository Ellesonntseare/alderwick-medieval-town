import bpy, pathlib, json
from mathutils import Vector, Matrix

ROOT=pathlib.Path(__file__).resolve().parents[1]
DOWNLOADS=pathlib.Path(r'C:\Users\elles\Downloads')
FILES=['saxon_warrior_-_t_pose.glb','bruce.glb','emlyn_-_game_character_design.glb','deadly_assassin_-_warrior_body_armor_weapons.glb','medieval (1).glb','cult_member_enemy_character.glb','medieval.glb']
reports=[]
bpy.ops.wm.read_factory_settings(use_empty=True)
for i, filename in enumerate(FILES):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(DOWNLOADS/filename))
    objects=[o for o in bpy.data.objects if o not in before]
    meshes=[o for o in objects if o.type=='MESH']
    points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    low=Vector([min(v[k] for v in points) for k in range(3)])
    high=Vector([max(v[k] for v in points) for k in range(3)])
    factor=1.8/(high.z-low.z)
    center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    rigs=[o for o in objects if o.type=='ARMATURE']
    report={'file':filename,'bounds':[list(low),list(high)],'parts':[(o.name,len(o.data.vertices)) for o in meshes],'rigs':[]}
    for rig in rigs:
        report['rigs'].append({'name':rig.name,'bones':{b.name:[list((rig.matrix_world@b.head_local-center)*factor),list((rig.matrix_world@b.tail_local-center)*factor)] for b in rig.data.bones}})
    reports.append(report)
    print('REMAINING_CHARACTER',filename,'bones',[(r['name'],len(r['bones'])) for r in report['rigs']],flush=True)
    for o in meshes:
        world=o.matrix_world.copy()
        o.parent=None
        o.data=o.data.copy()
        o.data.transform(world)
        for vertex in o.data.vertices:vertex.co=(vertex.co-center)*factor+Vector((i*2.2,0,0))
        o.matrix_world=Matrix.Identity(4)
        for mod in list(o.modifiers):o.modifiers.remove(mod)
    for o in objects:
        if o not in meshes:bpy.data.objects.remove(o,do_unlink=True)
(ROOT/'remaining-character-inspection.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.world=bpy.data.worlds.new('Review')
scene.world.color=(.16,.18,.20)
bpy.ops.object.camera_add(location=(6.6,-15,1.1))
cam=bpy.context.object
cam.rotation_euler=(Vector((6.6,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=16
scene.camera=cam
scene.render.resolution_x=2100
scene.render.resolution_y=600
scene.render.resolution_percentage=100
scene.render.filepath=str(ROOT/'remaining-character-sources.png')
bpy.ops.render.render(write_still=True)
