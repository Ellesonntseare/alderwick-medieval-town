import bpy, bmesh, pathlib, json, numpy as np
from mathutils import Vector, Matrix

ROOT=pathlib.Path(__file__).resolve().parents[1]
RUNNER=pathlib.Path(r'C:\Users\elles\Downloads\runner')
OUT=ROOT/'source-assets/medieval-runner-previews'
REVIEW=ROOT/'review/characters'
OUT.mkdir(parents=True,exist_ok=True)
reports=[]

def flatten(obj,graph):
    mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
    world=obj.matrix_world.copy()
    obj.parent=None
    obj.matrix_parent_inverse=Matrix.Identity(4)
    obj.data=mesh
    obj.data.transform(world)
    obj.matrix_world=Matrix.Identity(4)
    for modifier in list(obj.modifiers):obj.modifiers.remove(modifier)

for filename,style,outfit,scale,neck,head_height in [
    ('Running.fbx','runner_child','male_peasant',.67,1.0,.34),
    ('skins/Ch31_nonPBR.fbx','runner_youth','male_ranger',.85,1.28,.32),
]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'source-assets/assembled-outfits'/(outfit+'.glb')))
    prefix='Male_Peasant_' if outfit=='male_peasant' else 'Male_Ranger_'
    clothes=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(prefix)]
    for obj in list(bpy.data.objects):
        if obj not in clothes:bpy.data.objects.remove(obj,do_unlink=True)
    for obj in clothes:
        world=obj.matrix_world.copy()
        obj.parent=None
        obj.data.transform(world)
        obj.matrix_world=Matrix.Identity(4)
        for vertex in obj.data.vertices:
            vertex.co*=scale
            vertex.co.x*=1.1 if style=='runner_child' else 1.0
    if style=='runner_child':
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'source-assets/assembled-outfits/male_ranger.glb'))
        imported=[o for o in bpy.data.objects if o not in before]
        hoods=[o for o in imported if o.type=='MESH' and o.name.startswith('Male_Ranger_Head_Hood')]
        for obj in hoods:
            world=obj.matrix_world.copy()
            obj.parent=None
            obj.data.transform(world)
            obj.matrix_world=Matrix.Identity(4)
            for vertex in obj.data.vertices:
                point=vertex.co-Vector((0,0,1.57))
                vertex.co=Vector((point.x*1.3,point.y*1.3,point.z*1.02))+Vector((0,0,1.10))
        for obj in imported:
            if obj not in hoods:bpy.data.objects.remove(obj,do_unlink=True)
        clothes+=hoods
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(RUNNER/filename))
    imported=[o for o in bpy.data.objects if o not in before]
    for rig in [o for o in imported if o.type=='ARMATURE']:
        rig.animation_data_clear()
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get()
    heads=[]
    for obj in [o for o in imported if o.type=='MESH']:
        if any(word in obj.name.lower() for word in ['collar','sweater','pants','shoes']):continue
        groups={g.index for g in obj.vertex_groups if g.name.split(':')[-1] in ['Head','Neck','HairA','HairB']}
        hats={g.index for g in obj.vertex_groups if g.name.split(':')[-1]=='Hat'}
        if not groups:continue
        flatten(obj,graph)
        selected={v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.60 and sum(g.weight for g in v.groups if g.group in hats)<.15}
        if not selected:continue
        bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table();bm.verts.index_update()
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in selected],context='VERTS')
        bm.to_mesh(obj.data);bm.free()
        if len(obj.data.polygons):heads.append(obj);obj.vertex_groups.clear()
    for obj in imported:
        if obj not in heads:bpy.data.objects.remove(obj,do_unlink=True)
    if not heads:raise RuntimeError('No runner head found in '+filename)
    points=[v.co for obj in heads for v in obj.data.vertices]
    low=Vector(tuple(min(p[k] for p in points) for k in range(3)))
    high=Vector(tuple(max(p[k] for p in points) for k in range(3)))
    head_scale=head_height/(high.z-low.z)
    centre=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    for obj in heads:
        for vertex in obj.data.vertices:vertex.co=(vertex.co-centre)*head_scale+Vector((0,0,neck))
    if style=='runner_child':
        # Recolour the remaining source headwear liner inside the new cloth
        # hood. Work on copies packed into this derived model only.
        recoloured={}
        for obj in heads:
            for material in obj.data.materials:
                if not material or not material.use_nodes:continue
                for node in material.node_tree.nodes:
                    if node.type!='TEX_IMAGE' or not node.image or node.image.colorspace_settings.name!='sRGB':continue
                    original=node.image
                    if original.name not in recoloured:
                        image=original.copy()
                        image.name='Medieval headwear '+original.name
                        pixels=np.array(image.pixels[:],dtype=np.float32).reshape((-1,4))
                        red=(pixels[:,0]>.35)&(pixels[:,1]<pixels[:,0]*.58)&(pixels[:,2]<pixels[:,0]*.50)
                        shade=pixels[red,0].copy()
                        pixels[red,:3]=shade[:,None]*np.array([.36,.45,.24])
                        image.pixels.foreach_set(pixels.ravel())
                        image.update();image.pack()
                        recoloured[original.name]=image
                        print('MEDIEVAL_HEADWEAR_LINER',int(red.sum()),flush=True)
                    node.image=recoloured[original.name]
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(style+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(style+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
    reports.append({'style':style,'source':filename,'outfit':outfit,'height':neck+head_height,'head_parts':len(heads),'clothing_parts':len(clothes),'headwear':'cloth hood with recoloured liner' if style=='runner_child' else 'ranger hood'})
    print('MEDIEVAL_RUNNER_PREPARED',style,flush=True)
(OUT/'preview-manifest.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')

bpy.ops.wm.read_factory_settings(use_empty=True)
for index,item in enumerate(reports):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT/(item['style']+'.glb')))
    for obj in bpy.data.objects:
        if obj not in before and obj.parent is None:obj.location.x+=index*2.0
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_cavity=True
scene.display.shading.show_shadows=False
scene.world=bpy.data.worlds.new('Medieval runner preview')
scene.world.color=(.14,.17,.20)
bpy.ops.object.camera_add(location=(1,-10,1.8))
camera=bpy.context.object
camera.rotation_euler=(Vector((1,0,.78))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=4.7
scene.camera=camera
scene.render.resolution_x=1800
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.filepath=str(REVIEW/'runner-medieval-clothing-preview.png')
bpy.ops.render.render(write_still=True)
print('MEDIEVAL_RUNNER_PREVIEWS_RENDERED',flush=True)
