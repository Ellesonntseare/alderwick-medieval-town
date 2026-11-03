import bpy,pathlib,numpy as np
from mathutils import Vector
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(R/'game/downloaded/arnstein_castle.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH'];p=np.concatenate([np.array([(o.matrix_world@v.co)[:] for v in o.data.vertices]) for o in meshes]);tower=p[p[:,2]>10];print('ARNSTEIN_TOWER_BOUNDS',tower.min(0),tower.max(0),'MEDIAN',np.median(tower,0),flush=True)
for z in [2,4,6,8,10]:
 q=p[(p[:,2]>z-.2)&(p[:,2]<z+.2)];print('SLICE',z,'x',np.quantile(q[:,0],[.1,.5,.9]),'y',np.quantile(q[:,1],[.1,.5,.9]),flush=True)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.world=bpy.data.worlds.new('Review');scene.world.color=(.15,.17,.2);bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
for name,loc,look,size in [('top',(0,0,70),(0,0,0),60),('front',(42,-55,28),(0,0,7),60),('tower',(12,-17,22),(0,0,8),25)]:
 cam.location=loc;cam.rotation_euler=(Vector(look)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size;scene.render.filepath=str(R/('arnstein-layout-'+name+'.png'));bpy.ops.render.render(write_still=True)
