import bpy, pathlib, json, hashlib
from mathutils import Vector, Matrix

root=pathlib.Path(__file__).resolve().parents[1]
source=pathlib.Path(r"C:\Users\elles\Downloads\runner")
out=root/'review'/'characters'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
report=[]
files=['Running.fbx','skins/Ch31_nonPBR.fbx','skins/Fast Run.fbx','skins/Breakdance Freeze Var 2.fbx']
for index,filename in enumerate(files):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(source/filename))
    objects=[o for o in bpy.data.objects if o not in before]
    rigs=[o for o in objects if o.type=='ARMATURE']
    for rig in rigs:
        rig.animation_data_clear()
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get()
    meshes=[o for o in objects if o.type=='MESH']
    item={'file':filename,'meshes':[(o.name,len(o.data.vertices),[m.name if m else '' for m in o.data.materials]) for o in meshes], 'bones':list(rigs[0].data.bones.keys()) if rigs else []}
    points=[]
    for obj in meshes:
        obj.data=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
        world=obj.matrix_world.copy()
        obj.parent=None
        obj.data.transform(world)
        obj.matrix_world=Matrix.Identity(4)
        for mod in list(obj.modifiers):obj.modifiers.remove(mod)
        points.extend([v.co.copy() for v in obj.data.vertices])
    low=Vector(tuple(min(p[k] for p in points) for k in range(3)))
    high=Vector(tuple(max(p[k] for p in points) for k in range(3)))
    scale=1.4/(high.z-low.z)
    centre=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    for obj in meshes:
        for vertex in obj.data.vertices:vertex.co=(vertex.co-centre)*scale+Vector((index*1.9,0,0))
    for obj in objects:
        if obj not in meshes:bpy.data.objects.remove(obj,do_unlink=True)
    item['vertex_count']=sum(len(obj.data.vertices) for obj in meshes)
    report.append(item)
    print('RUNNER_SOURCE_INSPECTED',filename,item['vertex_count'],flush=True)
(out/'runner-source-inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_cavity=True
scene.display.shading.show_shadows=False
scene.world=bpy.data.worlds.new('Review')
scene.world.color=(.14,.17,.20)
bpy.ops.object.camera_add(location=(2.85,-12,1.6))
camera=bpy.context.object
camera.rotation_euler=(Vector((2.85,0,.75))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=8.1
scene.camera=camera
scene.render.resolution_x=2200
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.render.filepath=str(out/'runner-original-models.png')
bpy.ops.render.render(write_still=True)
