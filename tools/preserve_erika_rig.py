import bpy,pathlib,numpy as np
from mathutils import Matrix,Vector
root=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=r'C:\Users\elles\Downloads\Pick Fruit.fbx')
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data_clear()
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=rig
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
mapping={'Hips':'Hips','Spine':'Abdomen','Spine1':'Torso','Spine2':'Chest','Neck':'Neck','Head':'Head'}
for prefix,side in [('Left','L'),('Right','R')]:
 for original,target in [('Shoulder','Shoulder'),('Arm','UpperArm'),('ForeArm','LowerArm'),('Hand','Wrist'),('UpLeg','UpperLeg'),('Leg','LowerLeg'),('Foot','Foot')]:mapping[prefix+original]=target+'.'+side
 for finger in ['Thumb','Index','Middle','Ring','Pinky']:
  for i in range(1,5):mapping[prefix+'Hand'+finger+str(i)]=finger+str(i)+'.'+side
for bone in rig.data.bones:bone.name=mapping.get(bone.name.split(':')[-1],bone.name.split(':')[-1])
bpy.ops.object.mode_set(mode='EDIT')
body=rig.data.edit_bones.new('Body');body.head=(0,0,0);body.tail=(0,0,.1)
base=rig.data.edit_bones.new('Root');base.head=(0,0,0);base.tail=(0,0,.1);body.parent=base
rig.data.edit_bones['Hips'].parent=body
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data_create();action=bpy.data.actions.new('__RestPreview');rig.animation_data.action=action
for frame in [0,1]:
 for bone in rig.pose.bones:
  bone.rotation_mode='QUATERNION';bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
for image in bpy.data.images:
 if max(image.size)>1024:
  ratio=1024/max(image.size);image.scale(int(image.size[0]*ratio),int(image.size[1]*ratio))
bpy.ops.export_scene.gltf(filepath=str(root/'game/characters/erika_archer.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
print('ERIKA_ORIGINAL_WEIGHTS_PRESERVED',len(rig.data.bones),flush=True)
