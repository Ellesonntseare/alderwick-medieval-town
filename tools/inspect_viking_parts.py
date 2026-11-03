import bpy,pathlib
from mathutils import Vector,Matrix
R=pathlib.Path(r'C:\Users\elles\Desktop\Builts\Medieval-Town')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=r'C:\Users\elles\Downloads\gart220_female_viking.glb')
meshes=[o for o in bpy.data.objects if o.type=='MESH'];points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));scale=1.8/(high.z-low.z);center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
for i,o in enumerate(meshes):
 mat=o.matrix_world.copy();o.parent=None
 for v in o.data.vertices:v.co=(mat@v.co-center)*scale+Vector((i*2,0,0))
 o.matrix_world=Matrix.Identity(4);print('VIKING_PART',i,o.name,len(o.data.vertices),flush=True)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.world=bpy.data.worlds.new('Review');scene.world.color=(.14,.16,.19)
bpy.ops.object.camera_add(location=(2,-10,1.5));cam=bpy.context.object;cam.rotation_euler=(Vector((2,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=6.8;scene.camera=cam
scene.render.resolution_x=1500;scene.render.resolution_y=700;scene.render.resolution_percentage=100;scene.render.filepath=str(R/'viking-part-inspection.png');bpy.ops.render.render(write_still=True)
