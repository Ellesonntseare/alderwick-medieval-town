import bpy,json,pathlib,numpy as np
from mathutils import Vector

ROOT=pathlib.Path(__file__).resolve().parents[1]
DOWNLOADS=pathlib.Path(r'C:\Users\elles\Downloads')
results=[]
for asset_id,filename in [('fere_chateau','chateau_de_fere_en_tardenois_02.glb'),('montfaucon_chateau','chateau_de_montfaucon_25.glb')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(DOWNLOADS/filename))
    meshes=[o for o in bpy.data.objects if o.type=='MESH']
    points=np.concatenate([np.array([tuple(o.matrix_world@v.co) for v in o.data.vertices]) for o in meshes])
    low=points.min(0); high=points.max(0);centre=(low+high)*.5
    report={'id':asset_id,'file':filename,'bounds':[low.tolist(),high.tolist()],'size':(high-low).tolist(),'triangles':sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'height_percentiles':np.percentile(points[:,2],[0,2,5,10,20,30,50,70,90,100]).tolist()}
    results.append(report)
    scene=bpy.context.scene
    scene.render.engine='BLENDER_WORKBENCH'
    scene.display.shading.light='STUDIO'
    scene.display.shading.color_type='TEXTURE'
    scene.display.shading.show_cavity=True
    scene.world=bpy.data.worlds.new('Review')
    scene.world.color=(.12,.15,.12)
    scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
    bpy.ops.object.camera_add()
    camera=bpy.context.object;scene.camera=camera
    extent=max(high-low)
    for view,offset in [('above',(0,0,1)),('south',(1,-1,.7)),('north',(-1,1,.6))]:
        camera.location=Vector(centre)+Vector(offset)*extent*1.8
        camera.rotation_euler=(Vector(centre)-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.type='ORTHO';camera.data.ortho_scale=extent*1.3
        scene.render.filepath=str(ROOT/(asset_id+'-'+view+'.png'))
        bpy.ops.render.render(write_still=True)
    print('CHATEAU_SOURCE_INSPECTED',json.dumps(report),flush=True)
(ROOT/'new-chateaux-inspection.json').write_text(json.dumps(results,indent=2))
