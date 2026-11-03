import bpy, bmesh, pathlib, json
from mathutils import Vector, Matrix

ROOT=pathlib.Path(__file__).resolve().parents[1]
SOURCE=ROOT/'source-assets/characters/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits'
OUT=ROOT/'source-assets/assembled-outfits'
REVIEW=ROOT/'review/characters'
OUT.mkdir(parents=True,exist_ok=True)
REVIEW.mkdir(parents=True,exist_ok=True)

def flatten(obj,graph):
    mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
    world=obj.matrix_world.copy()
    obj.parent=None
    obj.matrix_parent_inverse=Matrix.Identity(4)
    obj.data=mesh
    obj.data.transform(world)
    obj.matrix_world=Matrix.Identity(4)
    for modifier in list(obj.modifiers):obj.modifiers.remove(modifier)

def add_head(base):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/characters'/f'{base}.glb'))
    imported=[o for o in bpy.data.objects if o not in before]
    for rig in [o for o in imported if o.type=='ARMATURE']:
        rig.animation_data_clear()
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get()
    result=[]
    for obj in [o for o in imported if o.type=='MESH']:
        groups={g.index for g in obj.vertex_groups if g.name in ['Head','Neck']}
        if not groups:continue
        flatten(obj,graph)
        selected={v.index for v in obj.data.vertices if v.co.z>1.41 and sum(g.weight for g in v.groups if g.group in groups)>.55}
        if not selected:continue
        bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table();bm.verts.index_update()
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in selected],context='VERTS')
        bm.to_mesh(obj.data);bm.free()
        if len(obj.data.polygons):
            obj.vertex_groups.clear()
            result.append(obj)
    for obj in imported:
        if obj not in result:bpy.data.objects.remove(obj,do_unlink=True)
    if not result:raise RuntimeError('No usable head extracted from '+base)
    return result

reports=[]
for filename,style,base in [('Male_Peasant','male_peasant','medieval'),('Female_Peasant','female_peasant','emlyn'),('Male_Ranger','male_ranger','medieval'),('Female_Ranger','female_ranger','emlyn')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/(filename+'.gltf')))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig.animation_data_clear()
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get()
    meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(filename+'_')]
    head=rig.matrix_world@rig.pose.bones['Head'].head
    landmarks={side:[rig.matrix_world@rig.pose.bones[bone+'_'+side].head for bone in ['upperarm','lowerarm','hand']] for side in ['l','r']}
    for obj in meshes:flatten(obj,graph)
    low=min(v.co.z for obj in meshes for v in obj.data.vertices)
    scale=1.57/(head.z-low)
    origin=Vector((head.x,head.y,low))
    for obj in meshes:
        for vertex in obj.data.vertices:vertex.co=(vertex.co-origin)*scale
        obj.vertex_groups.clear()
    arms=[list((point-origin)*scale) for point in landmarks['l']]
    for obj in list(bpy.data.objects):
        if obj not in meshes:bpy.data.objects.remove(obj,do_unlink=True)
    meshes+=add_head(base)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(style+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(style+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
    reports.append({'style':style,'source':filename+'.gltf','head_source':base,'arms':arms,'parts':len(meshes)})
    print('OUTFIT_PREVIEW_ASSEMBLED',style,len(meshes),flush=True)
(OUT/'outfit-fitting.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')

bpy.ops.wm.read_factory_settings(use_empty=True)
for index,item in enumerate(reports):
    with bpy.data.libraries.load(str(OUT/(item['style']+'.blend')),link=False) as (source,loaded):loaded.objects=source.objects
    for obj in loaded.objects:
        if obj:
            bpy.context.collection.objects.link(obj)
            if obj.parent is None:obj.location.x+=index*2.15
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_cavity=True
scene.display.shading.show_shadows=False
scene.world=bpy.data.worlds.new('Outfit preview')
scene.world.color=(.14,.17,.20)
bpy.ops.object.camera_add(location=(3.225,-12,2.1))
camera=bpy.context.object
camera.rotation_euler=(Vector((3.225,0,.85))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=9.0
scene.camera=camera
scene.render.resolution_x=2200
scene.render.resolution_y=1050
scene.render.resolution_percentage=100
scene.render.filepath=str(REVIEW/'four-medieval-outfit-previews.png')
bpy.ops.render.render(write_still=True)
print('FOUR_OUTFIT_PREVIEWS_RENDERED',flush=True)
